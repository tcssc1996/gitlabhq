<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { mapActions, mapState, mapGetters } from 'vuex';
import { getCookie, setCookie } from '~/lib/utils/common_utils';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import { VSA_METRICS_GROUPS } from '~/analytics/shared/constants';
import { toYmd, generateValueStreamsDashboardLink } from '~/analytics/shared/utils';
import PathNavigation from '~/analytics/cycle_analytics/components/path_navigation.vue';
import StageTable from '~/analytics/cycle_analytics/components/stage_table.vue';
import ValueStreamFilters from '~/analytics/cycle_analytics/components/value_stream_filters.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { __, s__ } from '~/locale';
import { SUMMARY_METRICS_REQUEST, METRICS_REQUESTS } from '../constants';

const OVERVIEW_DIALOG_COOKIE = 'cycle_analytics_help_dismissed';

export default {
  name: 'CycleAnalytics',
  components: {
    GlLoadingIcon,
    PathNavigation,
    StageTable,
    ValueStreamFilters,
    ValueStreamMetrics,
    UrlSync,
  },
  props: {
    noDataSvgPath: {
      type: String,
      required: true,
    },
    noAccessSvgPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isOverviewDialogDismissed: getCookie(OVERVIEW_DIALOG_COOKIE),
    };
  },
  computed: {
    ...mapState([
      'isLoading',
      'isLoadingStage',
      'isEmptyStage',
      'selectedStage',
      'selectedStageEvents',
      'selectedStageError',
      'stageCounts',
      'features',
      'createdBefore',
      'createdAfter',
      'pagination',
      'hasNoAccessError',
      'groupPath',
      'namespace',
    ]),
    ...mapGetters(['pathNavigationData', 'filterParams']),
    isLoaded() {
      return !this.isLoading && !this.isLoadingStage;
    },
    displayStageEvents() {
      const { selectedStageEvents, isLoadingStage, isEmptyStage } = this;
      return selectedStageEvents.length && !isLoadingStage && !isEmptyStage;
    },
    displayNotEnoughData() {
      return !this.isLoadingStage && this.isEmptyStage;
    },
    displayNoAccess() {
      return !this.isLoadingStage && this.hasNoAccessError;
    },
    displayPathNavigation() {
      return this.isLoading || (this.selectedStage && this.pathNavigationData.length);
    },
    emptyStageTitle() {
      if (this.displayNoAccess) {
        return __('You need permission.');
      }
      return this.selectedStageError
        ? this.selectedStageError
        : s__(
            'ValueStreamAnalyticsStage|There are 0 items to show in this stage, for these filters, within this time range.',
          );
    },
    emptyStageText() {
      if (this.displayNoAccess) {
        return __('Want to see the data? Please ask an administrator for access.');
      }
      return !this.selectedStageError && this.selectedStage?.emptyStageText
        ? this.selectedStage?.emptyStageText
        : '';
    },
    selectedStageCount() {
      if (this.selectedStage) {
        return this.stageCounts[this.selectedStage.id];
      }
      return 0;
    },
    hasCycleAnalyticsForGroups() {
      return this.features?.cycleAnalyticsForGroups;
    },
    metricsRequests() {
      return this.hasCycleAnalyticsForGroups ? METRICS_REQUESTS : SUMMARY_METRICS_REQUEST;
    },
    showLinkToDashboard() {
      return Boolean(this.features?.groupLevelAnalyticsDashboard && this.groupPath);
    },
    dashboardsPath() {
      const { fullPath } = this.namespace;
      return this.showLinkToDashboard
        ? generateValueStreamsDashboardLink(this.groupPath, [fullPath])
        : null;
    },
    query() {
      return {
        created_after: toYmd(this.createdAfter),
        created_before: toYmd(this.createdBefore),
        stage_id: this.selectedStage?.id || null,
        sort: this.pagination?.sort || null,
        direction: this.pagination?.direction || null,
        page: this.pagination?.page || null,
      };
    },
    filterBarNamespacePath() {
      return this.groupPath || this.namespace.fullPath;
    },
  },
  methods: {
    ...mapActions([
      'fetchStageData',
      'setSelectedStage',
      'setDateRange',
      'updateStageTablePagination',
    ]),
    onSetDateRange({ startDate, endDate }) {
      this.setDateRange({
        createdAfter: new Date(startDate),
        createdBefore: new Date(endDate),
      });
    },
    onSelectStage(stage) {
      this.setSelectedStage(stage);
      this.updateStageTablePagination({ ...this.pagination, page: 1 });
    },
    dismissOverviewDialog() {
      this.isOverviewDialogDismissed = true;
      setCookie(OVERVIEW_DIALOG_COOKIE, '1');
    },
    onHandleUpdatePagination(data) {
      this.updateStageTablePagination(data);
    },
  },
  dayRangeOptions: [7, 30, 90],
  i18n: {
    dropdownText: __('Last %{days} days'),
    pageTitle: __('Value Stream Analytics'),
    recentActivity: __('Recent Project Activity'),
  },
  VSA_METRICS_GROUPS,
};
</script>
<template>
  <div>
    <h3>{{ $options.i18n.pageTitle }}</h3>
    <value-stream-filters
      :namespace-path="filterBarNamespacePath"
      :has-project-filter="false"
      :start-date="createdAfter"
      :end-date="createdBefore"
      :group-path="groupPath"
      @setDateRange="onSetDateRange"
    />
    <div class="gl-display-flex gl-flex-direction-column gl-md-flex-direction-row">
      <path-navigation
        v-if="displayPathNavigation"
        data-testid="vsa-path-navigation"
        class="gl-w-full gl-mt-4"
        :loading="isLoading || isLoadingStage"
        :stages="pathNavigationData"
        :selected-stage="selectedStage"
        @selected="onSelectStage"
      />
    </div>
    <value-stream-metrics
      :request-path="namespace.fullPath"
      :request-params="filterParams"
      :requests="metricsRequests"
      :group-by="$options.VSA_METRICS_GROUPS"
      :dashboards-path="dashboardsPath"
    />
    <gl-loading-icon v-if="isLoading" size="lg" />
    <stage-table
      v-else
      :is-loading="isLoading || isLoadingStage"
      :stage-events="selectedStageEvents"
      :selected-stage="selectedStage"
      :stage-count="selectedStageCount"
      :empty-state-title="emptyStageTitle"
      :empty-state-message="emptyStageText"
      :no-data-svg-path="noDataSvgPath"
      :pagination="pagination"
      @handleUpdatePagination="onHandleUpdatePagination"
    />
    <url-sync v-if="isLoaded" :query="query" />
  </div>
</template>
