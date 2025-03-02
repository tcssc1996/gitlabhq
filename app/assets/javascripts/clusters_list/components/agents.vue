<script>
import { GlAlert, GlLoadingIcon, GlBanner } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { AGENT_FEEDBACK_ISSUE, AGENT_FEEDBACK_KEY } from '../constants';
import getAgentsQuery from '../graphql/queries/get_agents.query.graphql';
import { getAgentLastContact, getAgentStatus } from '../clusters_util';
import AgentEmptyState from './agent_empty_state.vue';
import AgentTable from './agent_table.vue';

export default {
  i18n: {
    feedbackBannerTitle: s__('ClusterAgents|Tell us what you think'),
    feedbackBannerText: s__(
      'ClusterAgents|We would love to learn more about your experience with the GitLab Agent.',
    ),
    feedbackBannerButton: s__('ClusterAgents|Give feedback'),
    error: s__('ClusterAgents|An error occurred while loading your agents'),
  },
  AGENT_FEEDBACK_ISSUE,
  AGENT_FEEDBACK_KEY,
  apollo: {
    agents: {
      query: getAgentsQuery,
      variables() {
        return {
          defaultBranchName: this.defaultBranchName,
          projectPath: this.projectPath,
        };
      },
      update(data) {
        this.updateTreeList(data);
        return data;
      },
      result() {
        this.emitAgentsLoaded();
      },
      error() {
        this.queryErrored = true;
      },
    },
  },
  components: {
    AgentEmptyState,
    AgentTable,
    GlAlert,
    GlLoadingIcon,
    GlBanner,
    LocalStorageSync,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['projectPath'],
  props: {
    defaultBranchName: {
      default: '.noBranch',
      required: false,
      type: String,
    },
    isChildComponent: {
      default: false,
      required: false,
      type: Boolean,
    },
    limit: {
      default: null,
      required: false,
      type: Number,
    },
  },
  data() {
    return {
      folderList: {},
      feedbackBannerDismissed: false,
      queryErrored: false,
    };
  },
  computed: {
    agentList() {
      const localAgents = this.agents?.project?.clusterAgents?.nodes || [];
      const sharedAgents = [
        ...(this.agents?.project?.ciAccessAuthorizedAgents?.nodes || []),
        ...(this.agents?.project?.userAccessAuthorizedAgents?.nodes || []),
      ].map((node) => {
        return {
          ...node.agent,
          isShared: true,
        };
      });

      const filteredList = [...localAgents, ...sharedAgents]
        .filter((node, index, list) => {
          return node && index === list.findIndex((agent) => agent.id === node.id);
        })
        .map((agent) => {
          const configFolder = this.folderList[agent.name];
          const lastContact = getAgentLastContact(agent?.tokens?.nodes);
          const status = getAgentStatus(lastContact);
          return { ...agent, configFolder, lastContact, status };
        })
        .sort((a, b) => b.lastUsedAt - a.lastUsedAt);

      return filteredList;
    },
    isLoading() {
      return this.$apollo.queries.agents.loading;
    },
    feedbackBannerEnabled() {
      return this.glFeatures.showGitlabAgentFeedback;
    },
    feedbackBannerClasses() {
      return this.isChildComponent ? 'gl-my-2' : 'gl-mb-4';
    },
  },
  methods: {
    updateTreeList(data) {
      const configFolders = data?.project?.repository?.tree?.trees?.nodes;

      if (configFolders) {
        configFolders.forEach((folder) => {
          this.folderList[folder.name] = folder;
        });
      }
    },
    emitAgentsLoaded() {
      this.$emit('onAgentsLoad', this.agentList?.length);
    },
    handleBannerClose() {
      this.feedbackBannerDismissed = true;
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="isLoading" size="lg" />

  <section v-else-if="!queryErrored">
    <div v-if="agentList.length">
      <local-storage-sync
        v-if="feedbackBannerEnabled"
        v-model="feedbackBannerDismissed"
        :storage-key="$options.AGENT_FEEDBACK_KEY"
      >
        <gl-banner
          v-if="!feedbackBannerDismissed"
          variant="introduction"
          :class="feedbackBannerClasses"
          :title="$options.i18n.feedbackBannerTitle"
          :button-text="$options.i18n.feedbackBannerButton"
          :button-link="$options.AGENT_FEEDBACK_ISSUE"
          @close="handleBannerClose"
        >
          <p>{{ $options.i18n.feedbackBannerText }}</p>
        </gl-banner>
      </local-storage-sync>

      <agent-table
        :agents="agentList"
        :default-branch-name="defaultBranchName"
        :max-agents="limit"
      />
    </div>

    <agent-empty-state v-else />
  </section>

  <gl-alert v-else variant="danger" :dismissible="false">
    {{ $options.i18n.error }}
  </gl-alert>
</template>
