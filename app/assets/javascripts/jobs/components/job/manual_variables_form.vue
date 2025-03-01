<script>
import {
  GlFormInputGroup,
  GlInputGroupText,
  GlFormInput,
  GlButton,
  GlLink,
  GlLoadingIcon,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { cloneDeep, uniqueId } from 'lodash';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { TYPENAME_CI_BUILD, TYPENAME_COMMIT_STATUS } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { JOB_GRAPHQL_ERRORS } from '~/jobs/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { redirectTo } from '~/lib/utils/url_utility'; // eslint-disable-line import/no-deprecated
import { s__ } from '~/locale';
import { reportMessageToSentry } from '~/jobs/utils';
import GetJob from './graphql/queries/get_job.query.graphql';
import playJobWithVariablesMutation from './graphql/mutations/job_play_with_variables.mutation.graphql';
import retryJobWithVariablesMutation from './graphql/mutations/job_retry_with_variables.mutation.graphql';

// This component is a port of ~/jobs/components/job/legacy_manual_variables_form.vue
// It is meant to fetch/update the job information via GraphQL instead of REST API.

export default {
  name: 'ManualVariablesForm',
  components: {
    GlFormInputGroup,
    GlInputGroupText,
    GlFormInput,
    GlButton,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['projectPath'],
  apollo: {
    variables: {
      query: GetJob,
      variables() {
        return {
          fullPath: this.projectPath,
          id: convertToGraphQLId(TYPENAME_COMMIT_STATUS, this.jobId),
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update(data) {
        const jobVariables = cloneDeep(data?.project?.job?.manualVariables?.nodes);
        return [...jobVariables.reverse(), ...this.variables];
      },
      error(error) {
        createAlert({ message: JOB_GRAPHQL_ERRORS.jobQueryErrorText });
        reportMessageToSentry(this.$options.name, error, {});
      },
    },
  },
  props: {
    isRetryable: {
      type: Boolean,
      required: true,
    },
    jobId: {
      type: Number,
      required: true,
    },
  },
  clearBtnSharedClasses: ['gl-flex-grow-0 gl-flex-basis-0 gl-m-0! gl-ml-3!'],
  inputTypes: {
    key: 'key',
    value: 'value',
  },
  i18n: {
    cancel: s__('CiVariables|Cancel'),
    removeInputs: s__('CiVariables|Remove inputs'),
    formHelpText: s__(
      'CiVariables|Specify variable values to be used in this run. The variables specified in the configuration file and %{linkStart}CI/CD settings%{linkEnd} are used by default.',
    ),
    overrideNoteText: s__(
      'CiVariables|Variables specified here are %{boldStart}expanded%{boldEnd} and not %{boldStart}masked.%{boldEnd}',
    ),
    header: s__('CiVariables|Variables'),
    keyLabel: s__('CiVariables|Key'),
    keyPlaceholder: s__('CiVariables|Input variable key'),
    runAgainButtonText: s__('CiVariables|Run job again'),
    runButtonText: s__('CiVariables|Run job'),
    valueLabel: s__('CiVariables|Value'),
    valuePlaceholder: s__('CiVariables|Input variable value'),
  },
  data() {
    return {
      job: {},
      variables: [
        {
          id: uniqueId(),
          key: '',
          value: '',
        },
      ],
      runBtnDisabled: false,
    };
  },
  computed: {
    mutationVariables() {
      return {
        id: convertToGraphQLId(TYPENAME_CI_BUILD, this.jobId),
        variables: this.preparedVariables,
      };
    },
    preparedVariables() {
      return this.variables
        .filter((variable) => variable.key !== '')
        .map(({ key, value }) => ({ key, value }));
    },
    runBtnText() {
      return this.isRetryable
        ? this.$options.i18n.runAgainButtonText
        : this.$options.i18n.runButtonText;
    },
    variableSettings() {
      return helpPagePath('ci/variables/index', { anchor: 'add-a-cicd-variable-to-a-project' });
    },
  },
  methods: {
    async playJob() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: playJobWithVariablesMutation,
          variables: this.mutationVariables,
        });
        if (data.jobPlay?.errors?.length) {
          createAlert({ message: data.jobPlay.errors[0] });
        } else {
          this.navigateToJob(data.jobPlay?.job?.webPath);
        }
      } catch (error) {
        createAlert({ message: JOB_GRAPHQL_ERRORS.jobMutationErrorText });
        reportMessageToSentry(this.$options.name, error, {});
      }
    },
    async retryJob() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: retryJobWithVariablesMutation,
          variables: this.mutationVariables,
        });
        if (data.jobRetry?.errors?.length) {
          createAlert({ message: data.jobRetry.errors[0] });
        } else {
          this.navigateToJob(data.jobRetry?.job?.webPath);
        }
      } catch (error) {
        createAlert({ message: JOB_GRAPHQL_ERRORS.jobMutationErrorText });
        reportMessageToSentry(this.$options.name, error, {});
      }
    },
    addEmptyVariable() {
      const lastVar = this.variables[this.variables.length - 1];

      if (lastVar.key === '') {
        return;
      }

      this.variables.push({
        id: uniqueId(),
        key: '',
        value: '',
      });
    },
    canRemove(index) {
      return index < this.variables.length - 1;
    },
    deleteVariable(id) {
      this.variables.splice(
        this.variables.findIndex((el) => el.id === id),
        1,
      );
    },
    inputRef(type, id) {
      return `${this.$options.inputTypes[type]}-${id}`;
    },
    navigateToJob(path) {
      redirectTo(path); // eslint-disable-line import/no-deprecated
    },
    runJob() {
      this.runBtnDisabled = true;

      if (this.isRetryable) {
        this.retryJob();
      } else {
        this.playJob();
      }
    },
  },
};
</script>
<template>
  <gl-loading-icon v-if="$apollo.queries.variables.loading" class="gl-mt-9" size="lg" />
  <div v-else class="row gl-justify-content-center">
    <div class="col-10" data-testid="manual-vars-form">
      <label>{{ $options.i18n.header }}</label>

      <div
        v-for="(variable, index) in variables"
        :key="variable.id"
        class="gl-display-flex gl-align-items-center gl-mb-5"
        data-testid="ci-variable-row"
      >
        <gl-form-input-group class="gl-mr-4 gl-flex-grow-1">
          <template #prepend>
            <gl-input-group-text>
              {{ $options.i18n.keyLabel }}
            </gl-input-group-text>
          </template>
          <gl-form-input
            :ref="inputRef('key', variable.id)"
            v-model="variable.key"
            :placeholder="$options.i18n.keyPlaceholder"
            data-testid="ci-variable-key"
            @change="addEmptyVariable"
          />
        </gl-form-input-group>

        <gl-form-input-group class="gl-flex-grow-2">
          <template #prepend>
            <gl-input-group-text>
              {{ $options.i18n.valueLabel }}
            </gl-input-group-text>
          </template>
          <gl-form-input
            :ref="inputRef('value', variable.id)"
            v-model="variable.value"
            :placeholder="$options.i18n.valuePlaceholder"
            data-testid="ci-variable-value"
          />
        </gl-form-input-group>

        <gl-button
          v-if="canRemove(index)"
          v-gl-tooltip
          :aria-label="$options.i18n.removeInputs"
          :title="$options.i18n.removeInputs"
          :class="$options.clearBtnSharedClasses"
          category="tertiary"
          icon="remove"
          data-testid="delete-variable-btn"
          @click="deleteVariable(variable.id)"
        />
        <!-- Placeholder button to keep the layout fixed -->
        <gl-button
          v-else
          class="gl-opacity-0 gl-pointer-events-none"
          :class="$options.clearBtnSharedClasses"
          data-testid="delete-variable-btn-placeholder"
          category="tertiary"
          icon="remove"
        />
      </div>

      <div class="gl-text-center gl-mt-5">
        <gl-sprintf :message="$options.i18n.formHelpText">
          <template #link="{ content }">
            <gl-link :href="variableSettings" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </div>
      <div class="gl-text-center gl-mt-3">
        <gl-sprintf :message="$options.i18n.overrideNoteText">
          <template #bold="{ content }">
            <strong>
              {{ content }}
            </strong>
          </template>
        </gl-sprintf>
      </div>
      <div class="gl-display-flex gl-justify-content-center gl-mt-5">
        <gl-button
          v-if="isRetryable"
          class="gl-mt-5"
          data-testid="cancel-btn"
          @click="$emit('hideManualVariablesForm')"
          >{{ $options.i18n.cancel }}</gl-button
        >
        <gl-button
          class="gl-mt-5"
          variant="confirm"
          category="primary"
          :disabled="runBtnDisabled"
          data-testid="run-manual-job-btn"
          @click="runJob"
        >
          {{ runBtnText }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
