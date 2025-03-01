<script>
import { GlButton, GlModalDirective, GlTooltipDirective as GlTooltip, GlSprintf } from '@gitlab/ui';
import csrf from '~/lib/utils/csrf';
import { __, s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import DeleteEnvironmentModal from './delete_environment_modal.vue';
import StopEnvironmentModal from './stop_environment_modal.vue';
import DeployFreezeAlert from './deploy_freeze_alert.vue';

export default {
  name: 'EnvironmentsDetailHeader',
  csrf,
  components: {
    GlButton,
    GlSprintf,
    TimeAgo,
    DeployFreezeAlert,
    DeleteEnvironmentModal,
    StopEnvironmentModal,
  },
  directives: {
    GlModalDirective,
    GlTooltip,
  },
  mixins: [timeagoMixin, glFeatureFlagsMixin()],
  props: {
    environment: {
      type: Object,
      required: true,
    },
    canAdminEnvironment: {
      type: Boolean,
      required: true,
    },
    canUpdateEnvironment: {
      type: Boolean,
      required: true,
    },
    canDestroyEnvironment: {
      type: Boolean,
      required: true,
    },
    canStopEnvironment: {
      type: Boolean,
      required: true,
    },
    cancelAutoStopPath: {
      type: String,
      required: false,
      default: '',
    },
    metricsPath: {
      type: String,
      required: false,
      default: '',
    },
    updatePath: {
      type: String,
      required: false,
      default: '',
    },
    terminalPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  i18n: {
    autoStopAtText: s__('Environments|Auto stops %{autoStopAt}'),
    metricsButtonTitle: __('See metrics'),
    metricsButtonText: __('Monitoring'),
    editButtonText: __('Edit'),
    stopButtonText: s__('Environments|Stop'),
    deleteButtonText: s__('Environments|Delete'),
    externalButtonTitle: s__('Environments|Open live environment'),
    externalButtonText: __('View deployment'),
    cancelAutoStopButtonTitle: __('Prevent environment from auto-stopping'),
  },
  computed: {
    shouldShowCancelAutoStopButton() {
      return this.environment.isAvailable && Boolean(this.environment.autoStopAt);
    },
    shouldShowExternalUrlButton() {
      return Boolean(this.environment.externalUrl);
    },
    shouldShowStopButton() {
      return this.canStopEnvironment && this.environment.isAvailable;
    },
    shouldShowTerminalButton() {
      return this.canAdminEnvironment && this.environment.hasTerminals;
    },
    shouldShowMetricsButton() {
      return Boolean(!this.glFeatures.removeMonitorMetrics && this.shouldShowExternalUrlButton);
    },
  },
};
</script>
<template>
  <div>
    <deploy-freeze-alert :name="environment.name" />
    <header class="top-area gl-justify-content-between">
      <div class="gl-display-flex gl-flex-grow-1 gl-align-items-center">
        <h1 class="page-title gl-font-size-h-display">
          {{ environment.name }}
        </h1>
        <p
          v-if="shouldShowCancelAutoStopButton"
          class="gl-mb-0 gl-ml-3"
          data-testid="auto-stops-at"
        >
          <gl-sprintf :message="$options.i18n.autoStopAtText">
            <template #autoStopAt>
              <time-ago :time="environment.autoStopAt" />
            </template>
          </gl-sprintf>
        </p>
      </div>
      <div class="nav-controls gl-my-1">
        <form method="POST" :action="cancelAutoStopPath" data-testid="cancel-auto-stop-form">
          <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
          <gl-button
            v-if="shouldShowCancelAutoStopButton"
            v-gl-tooltip.hover
            data-testid="cancel-auto-stop-button"
            :title="$options.i18n.cancelAutoStopButtonTitle"
            type="submit"
            icon="thumbtack"
          />
        </form>
        <gl-button
          v-if="shouldShowTerminalButton"
          data-testid="terminal-button"
          :href="terminalPath"
          icon="terminal"
        />
        <gl-button
          v-if="shouldShowExternalUrlButton"
          v-gl-tooltip.hover
          data-testid="external-url-button"
          :title="$options.i18n.externalButtonTitle"
          :href="environment.externalUrl"
          is-unsafe-link
          icon="external-link"
          target="_blank"
          >{{ $options.i18n.externalButtonText }}</gl-button
        >
        <gl-button
          v-if="shouldShowMetricsButton"
          v-gl-tooltip.hover
          data-testid="metrics-button"
          :href="metricsPath"
          :title="$options.i18n.metricsButtonTitle"
          icon="chart"
          class="gl-mr-2"
        >
          {{ $options.i18n.metricsButtonText }}
        </gl-button>
        <gl-button v-if="canUpdateEnvironment" data-testid="edit-button" :href="updatePath">
          {{ $options.i18n.editButtonText }}
        </gl-button>
        <gl-button
          v-if="shouldShowStopButton"
          v-gl-modal-directive="'stop-environment-modal'"
          data-testid="stop-button"
          icon="stop"
          variant="danger"
        >
          {{ $options.i18n.stopButtonText }}
        </gl-button>
        <gl-button
          v-if="canDestroyEnvironment"
          v-gl-modal-directive="'delete-environment-modal'"
          data-testid="destroy-button"
          variant="danger"
        >
          {{ $options.i18n.deleteButtonText }}
        </gl-button>
      </div>
      <delete-environment-modal v-if="canDestroyEnvironment" :environment="environment" />
      <stop-environment-modal v-if="shouldShowStopButton" :environment="environment" />
    </header>
  </div>
</template>
