<script>
import { createAlert } from '~/alert';
import commitReferencesQuery from '../graphql/queries/commit_references.query.graphql';
import containingBranchesQuery from '../graphql/queries/commit_containing_branches.query.graphql';
import containingTagsQuery from '../graphql/queries/commit_containing_tags.query.graphql';
import {
  BRANCHES,
  TAGS,
  FETCH_CONTAINING_REFS_EVENT,
  FETCH_COMMIT_REFERENCES_ERROR,
} from '../constants';
import RefsList from './refs_list.vue';

export default {
  name: 'CommitRefs',
  components: {
    RefsList,
  },
  inject: ['fullPath', 'commitSha'],
  apollo: {
    project: {
      query: commitReferencesQuery,
      variables() {
        return this.queryVariables;
      },
      update({
        project: {
          commitReferences: { tippingTags, tippingBranches, containingBranches, containingTags },
        },
      }) {
        this.tippingTags = tippingTags.names;
        this.tippingBranches = tippingBranches.names;
        this.hasContainingBranches = Boolean(containingBranches.names.length);
        this.hasContainingTags = Boolean(containingTags.names.length);
      },
      error() {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
        });
      },
    },
  },
  data() {
    return {
      containingTags: [],
      containingBranches: [],
      tippingTags: [],
      tippingBranches: [],
      hasContainingBranches: false,
      hasContainingTags: false,
    };
  },
  computed: {
    hasBranches() {
      return this.tippingBranches.length || this.hasContainingBranches;
    },
    hasTags() {
      return this.tippingTags.length || this.hasContainingTags;
    },
    queryVariables() {
      return {
        fullPath: this.fullPath,
        commitSha: this.commitSha,
      };
    },
  },
  methods: {
    async fetchContainingRefs({ query, namespace }) {
      try {
        const { data } = await this.$apollo.query({
          query,
          variables: this.queryVariables,
        });
        this[namespace] = data.project.commitReferences[namespace].names;
        return data.project.commitReferences[namespace].names;
      } catch {
        return createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
        });
      }
    },
    fetchContainingBranches() {
      this.fetchContainingRefs({ query: containingBranchesQuery, namespace: 'containingBranches' });
    },
    fetchContainingTags() {
      this.fetchContainingRefs({ query: containingTagsQuery, namespace: 'containingTags' });
    },
  },
  i18n: {
    branches: BRANCHES,
    tags: TAGS,
    errorMessage: FETCH_COMMIT_REFERENCES_ERROR,
  },
  fetchContainingRefsEvent: FETCH_CONTAINING_REFS_EVENT,
};
</script>

<template>
  <div class="gl-ml-7">
    <refs-list
      v-if="hasBranches"
      :has-containing-refs="hasContainingBranches"
      :is-loading="$apollo.queries.project.loading"
      :tipping-refs="tippingBranches"
      :containing-refs="containingBranches"
      :namespace="$options.i18n.branches"
      @[$options.fetchContainingRefsEvent]="fetchContainingBranches"
    />
    <refs-list
      v-if="hasTags"
      :has-containing-refs="hasContainingTags"
      :is-loading="$apollo.queries.project.loading"
      :tipping-refs="tippingTags"
      :containing-refs="containingTags"
      :namespace="$options.i18n.tags"
      @[$options.fetchContainingRefsEvent]="fetchContainingTags"
    />
  </div>
</template>
