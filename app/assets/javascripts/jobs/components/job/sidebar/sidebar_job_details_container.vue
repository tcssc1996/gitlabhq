<script>
import { mapState } from 'vuex';
import { GlBadge } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { timeIntervalInWords } from '~/lib/utils/datetime_utility';
import { __, sprintf } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import DetailRow from './sidebar_detail_row.vue';

export default {
  name: 'JobSidebarDetailsContainer',
  components: {
    DetailRow,
    GlBadge,
  },
  mixins: [timeagoMixin],
  computed: {
    ...mapState(['job']),
    coverage() {
      return `${this.job.coverage}%`;
    },
    duration() {
      return timeIntervalInWords(this.job.duration);
    },
    durationTitle() {
      return this.job.finished_at ? __('Duration') : __('Elapsed time');
    },
    erasedAt() {
      return this.timeFormatted(this.job.erased_at);
    },
    finishedAt() {
      return this.timeFormatted(this.job.finished_at);
    },
    hasTags() {
      return this.job?.tags?.length;
    },
    hasTimeout() {
      return this.job?.metadata?.timeout_human_readable ?? false;
    },
    hasAnyDetail() {
      return Boolean(
        this.job.duration ||
          this.job.finished_at ||
          this.job.erased_at ||
          this.job.queued_duration ||
          this.job.runner ||
          this.job.coverage,
      );
    },
    runnerId() {
      const { id, short_sha: token, description } = this.job.runner;

      return `#${id} (${token}) ${description}`;
    },
    queuedDuration() {
      return timeIntervalInWords(this.job.queued_duration);
    },
    shouldRenderBlock() {
      return Boolean(this.hasAnyDetail || this.hasTimeout || this.hasTags);
    },
    timeout() {
      return `${this.job?.metadata?.timeout_human_readable}${this.timeoutSource}`;
    },
    timeoutSource() {
      if (!this.job?.metadata?.timeout_source) {
        return '';
      }

      return sprintf(__(' (from %{timeoutSource})'), {
        timeoutSource: this.job.metadata.timeout_source,
      });
    },
    runnerAdminPath() {
      return this.job?.runner?.admin_path || '';
    },
  },
  i18n: {
    COVERAGE: __('Coverage'),
    FINISHED: __('Finished'),
    ERASED: __('Erased'),
    QUEUED: __('Queued'),
    RUNNER: __('Runner'),
    TAGS: __('Tags:'),
    TIMEOUT: __('Timeout'),
  },
  TIMEOUT_HELP_URL: helpPagePath('/ci/pipelines/settings.md', {
    anchor: 'set-a-limit-for-how-long-jobs-can-run',
  }),
};
</script>

<template>
  <div v-if="shouldRenderBlock">
    <detail-row v-if="job.duration" :value="duration" :title="durationTitle" />
    <detail-row
      v-if="job.finished_at"
      :value="finishedAt"
      data-testid="job-finished"
      :title="$options.i18n.FINISHED"
    />
    <detail-row v-if="job.erased_at" :value="erasedAt" :title="$options.i18n.ERASED" />
    <detail-row v-if="job.queued_duration" :value="queuedDuration" :title="$options.i18n.QUEUED" />
    <detail-row
      v-if="hasTimeout"
      :help-url="$options.TIMEOUT_HELP_URL"
      :value="timeout"
      data-testid="job-timeout"
      :title="$options.i18n.TIMEOUT"
    />
    <detail-row
      v-if="job.runner"
      :value="runnerId"
      :title="$options.i18n.RUNNER"
      :path="runnerAdminPath"
    />
    <detail-row v-if="job.coverage" :value="coverage" :title="$options.i18n.COVERAGE" />

    <p v-if="hasTags" class="build-detail-row" data-testid="job-tags">
      <span class="font-weight-bold">{{ $options.i18n.TAGS }}</span>
      <gl-badge v-for="(tag, i) in job.tags" :key="i" variant="info">{{ tag }}</gl-badge>
    </p>
  </div>
</template>
