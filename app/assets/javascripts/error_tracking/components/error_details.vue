<script>
import {
  GlButton,
  GlFormInput,
  GlLoadingIcon,
  GlBadge,
  GlAlert,
  GlSprintf,
  GlDropdown,
  GlDropdownItem,
  GlDropdownDivider,
} from '@gitlab/ui';
import { mapActions, mapGetters, mapState } from 'vuex';
import { createAlert, VARIANT_WARNING } from '~/alert';
import { __, sprintf, n__ } from '~/locale';
import Tracking from '~/tracking';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import query from '../queries/details.query.graphql';
import {
  trackErrorDetailsViewsOptions,
  trackErrorStatusUpdateOptions,
  trackCreateIssueFromError,
} from '../events_tracking';
import { severityLevel, severityLevelVariant, errorStatus } from '../constants';
import Stacktrace from './stacktrace.vue';
import ErrorDetailsInfo from './error_details_info.vue';

const SENTRY_TIMEOUT = 10000;

export default {
  components: {
    GlButton,
    GlFormInput,
    GlLoadingIcon,
    TooltipOnTruncate,
    Stacktrace,
    GlBadge,
    GlAlert,
    GlSprintf,
    GlDropdown,
    GlDropdownItem,
    GlDropdownDivider,
    TimeAgoTooltip,
    ErrorDetailsInfo,
  },
  props: {
    issueUpdatePath: {
      type: String,
      required: true,
    },
    issueId: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    issueStackTracePath: {
      type: String,
      required: true,
    },
    projectIssuesPath: {
      type: String,
      required: true,
    },
    csrfToken: {
      type: String,
      required: true,
    },
  },
  apollo: {
    error: {
      query,
      variables() {
        return {
          fullPath: this.projectPath,
          errorId: `gid://gitlab/Gitlab::ErrorTracking::DetailedError/${this.issueId}`,
        };
      },
      pollInterval: 2000,
      update: (data) => data.project.sentryErrors.detailedError,
      error: () =>
        createAlert({
          message: __('Failed to load error details from Sentry.'),
        }),
      result(res) {
        if (res.data.project?.sentryErrors?.detailedError) {
          this.$apollo.queries.error.stopPolling();
          this.setStatus(this.error.status);
        } else {
          this.onNoApolloResult();
        }
      },
    },
  },
  data() {
    return {
      error: null,
      errorLoading: true,
      errorPollTimeout: 0,
      issueCreationInProgress: false,
      isAlertVisible: false,
      isStacktraceEmptyAlertVisible: true,
      closedIssueId: null,
    };
  },
  computed: {
    ...mapState('details', [
      'loadingStacktrace',
      'stacktraceData',
      'updatingResolveStatus',
      'updatingIgnoreStatus',
      'errorStatus',
    ]),
    ...mapGetters('details', ['stacktrace']),

    showStacktrace() {
      return Boolean(this.stacktrace?.length);
    },
    issueTitle() {
      return this.error.title;
    },
    issueDescription() {
      return sprintf(
        __(
          '%{description}- Sentry event: %{errorUrl}- First seen: %{firstSeen}- Last seen: %{lastSeen} %{countLabel}: %{count}%{userCountLabel}: %{userCount}',
        ),
        {
          description: '# Error Details:\n',
          errorUrl: `${this.error.externalUrl}\n`,
          firstSeen: `\n${this.error.firstSeen}\n`,
          lastSeen: `${this.error.lastSeen}\n`,
          countLabel: n__('- Event', '- Events', this.error.count),
          count: `${this.error.count}\n`,
          userCountLabel: n__('- User', '- Users', this.error.userCount),
          userCount: `${this.error.userCount}\n`,
        },
        false,
      );
    },
    issueUpdateInProgress() {
      return (
        this.updatingIgnoreStatus || this.updatingResolveStatus || this.issueCreationInProgress
      );
    },
    errorLevel() {
      return sprintf(__('level: %{level}'), { level: this.error.tags.level });
    },
    errorSeverityVariant() {
      return (
        severityLevelVariant[this.error.tags.level] || severityLevelVariant[severityLevel.ERROR]
      );
    },
    ignoreBtnLabel() {
      return this.errorStatus !== errorStatus.IGNORED ? __('Ignore') : __('Undo ignore');
    },
    resolveBtnLabel() {
      return this.errorStatus !== errorStatus.RESOLVED ? __('Resolve') : __('Unresolve');
    },
    showEmptyStacktraceAlert() {
      return !this.loadingStacktrace && !this.showStacktrace && this.isStacktraceEmptyAlertVisible;
    },
  },
  watch: {
    error(val) {
      if (val) {
        this.errorLoading = false;
      }
    },
  },
  mounted() {
    this.trackPageViews();
    this.startPollingStacktrace(this.issueStackTracePath);
    this.errorPollTimeout = Date.now() + SENTRY_TIMEOUT;
    this.$apollo.queries.error.setOptions({
      fetchPolicy: 'cache-and-network',
    });
  },
  methods: {
    ...mapActions('details', [
      'startPollingStacktrace',
      'updateStatus',
      'setStatus',
      'updateResolveStatus',
      'updateIgnoreStatus',
    ]),
    createIssue() {
      this.issueCreationInProgress = true;
      const { category, action } = trackCreateIssueFromError;
      Tracking.event(category, action);
      this.$refs.sentryIssueForm.submit();
    },
    onIgnoreStatusUpdate() {
      const status =
        this.errorStatus === errorStatus.IGNORED ? errorStatus.UNRESOLVED : errorStatus.IGNORED;
      // eslint-disable-next-line promise/catch-or-return
      this.updateIgnoreStatus({ endpoint: this.issueUpdatePath, status }).then(() => {
        this.trackStatusUpdate(status);
      });
    },
    onResolveStatusUpdate() {
      const status =
        this.errorStatus === errorStatus.RESOLVED ? errorStatus.UNRESOLVED : errorStatus.RESOLVED;

      // eslint-disable-next-line promise/catch-or-return
      this.updateResolveStatus({ endpoint: this.issueUpdatePath, status }).then((res) => {
        this.closedIssueId = res.closed_issue_iid;
        if (this.closedIssueId) {
          this.isAlertVisible = true;
        }
        this.trackStatusUpdate(status);
      });
    },
    onNoApolloResult() {
      if (Date.now() > this.errorPollTimeout) {
        this.$apollo.queries.error.stopPolling();
        this.errorLoading = false;
        createAlert({
          message: __('Could not connect to Sentry. Refresh the page to try again.'),
          variant: VARIANT_WARNING,
        });
      }
    },
    trackPageViews() {
      const { category, action } = trackErrorDetailsViewsOptions;
      Tracking.event(category, action);
    },
    trackStatusUpdate(status) {
      const { category, action } = trackErrorStatusUpdateOptions(status);
      Tracking.event(category, action);
    },
  },
};
</script>

<template>
  <div>
    <div v-if="errorLoading" class="py-3">
      <gl-loading-icon size="lg" />
    </div>

    <div v-else-if="error" class="error-details">
      <gl-alert v-if="isAlertVisible" @dismiss="isAlertVisible = false">
        <gl-sprintf
          :message="
            __('The associated issue #%{issueId} has been closed as the error is now resolved.')
          "
        >
          <template #issueId>
            <span>{{ closedIssueId }}</span>
          </template>
        </gl-sprintf>
      </gl-alert>

      <gl-alert v-if="showEmptyStacktraceAlert" @dismiss="isStacktraceEmptyAlertVisible = false">
        {{ __('No stack trace for this error') }}
      </gl-alert>

      <div class="error-details-header d-flex py-2 justify-content-between">
        <div
          v-if="!loadingStacktrace && stacktrace"
          class="error-details-meta my-auto"
          data-qa-selector="reported_text"
        >
          <gl-sprintf :message="__('Reported %{timeAgo} by %{reportedBy}')">
            <template #reportedBy>
              <strong class="error-details-meta-culprit">{{ error.culprit }}</strong>
            </template>
            <template #timeAgo>
              <time-ago-tooltip :time="stacktraceData.date_received" />
            </template>
          </gl-sprintf>
        </div>
        <div class="error-details-actions">
          <div class="d-inline-flex bv-d-sm-down-none">
            <gl-button
              :loading="updatingIgnoreStatus"
              data-testid="update-ignore-status-btn"
              @click="onIgnoreStatusUpdate"
            >
              {{ ignoreBtnLabel }}
            </gl-button>
            <gl-button
              class="ml-2"
              category="secondary"
              variant="confirm"
              :loading="updatingResolveStatus"
              data-testid="update-resolve-status-btn"
              @click="onResolveStatusUpdate"
            >
              {{ resolveBtnLabel }}
            </gl-button>
            <gl-button
              v-if="error.gitlabIssuePath"
              class="ml-2"
              data-testid="view_issue_button"
              :href="error.gitlabIssuePath"
              variant="confirm"
            >
              {{ __('View issue') }}
            </gl-button>
            <form
              ref="sentryIssueForm"
              :action="projectIssuesPath"
              method="POST"
              class="d-inline-block ml-2"
            >
              <gl-form-input class="hidden" name="issue[title]" :value="issueTitle" />
              <input name="issue[description]" :value="issueDescription" type="hidden" />
              <gl-form-input
                :value="error.sentryId"
                class="hidden"
                name="issue[sentry_issue_attributes][sentry_issue_identifier]"
              />
              <gl-form-input :value="csrfToken" class="hidden" name="authenticity_token" />
              <gl-button
                v-if="!error.gitlabIssuePath"
                category="primary"
                variant="confirm"
                :loading="issueCreationInProgress"
                data-qa-selector="create_issue_button"
                @click="createIssue"
              >
                {{ __('Create issue') }}
              </gl-button>
            </form>
          </div>
          <gl-dropdown
            text="Options"
            class="error-details-options d-md-none"
            right
            :disabled="issueUpdateInProgress"
          >
            <gl-dropdown-item
              data-qa-selector="update_ignore_status_button"
              @click="onIgnoreStatusUpdate"
              >{{ ignoreBtnLabel }}</gl-dropdown-item
            >
            <gl-dropdown-item
              data-qa-selector="update_resolve_status_button"
              @click="onResolveStatusUpdate"
              >{{ resolveBtnLabel }}</gl-dropdown-item
            >
            <gl-dropdown-divider />
            <gl-dropdown-item
              v-if="error.gitlabIssuePath"
              data-qa-selector="view_issue_button"
              :href="error.gitlabIssuePath"
              >{{ __('View issue') }}</gl-dropdown-item
            >
            <gl-dropdown-item
              v-if="!error.gitlabIssuePath"
              :loading="issueCreationInProgress"
              data-qa-selector="create_issue_button"
              @click="createIssue"
              >{{ __('Create issue') }}</gl-dropdown-item
            >
          </gl-dropdown>
        </div>
      </div>
      <div>
        <tooltip-on-truncate :title="error.title" truncate-target="child" placement="top">
          <h2 class="text-truncate">{{ error.title }}</h2>
        </tooltip-on-truncate>
        <template v-if="error.tags">
          <gl-badge v-if="error.tags.level" :variant="errorSeverityVariant" class="gl-mr-3">
            {{ errorLevel }}
          </gl-badge>
          <gl-badge v-if="error.tags.logger" variant="muted">{{ error.tags.logger }} </gl-badge>
        </template>

        <error-details-info :error="error" />

        <div v-if="loadingStacktrace" class="py-3">
          <gl-loading-icon size="lg" />
        </div>

        <template v-else-if="showStacktrace">
          <h3 class="my-4">{{ __('Stack trace') }}</h3>
          <stacktrace :entries="stacktrace" />
        </template>
      </div>
    </div>
  </div>
</template>
