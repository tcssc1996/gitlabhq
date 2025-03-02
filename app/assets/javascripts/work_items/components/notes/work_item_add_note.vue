<script>
import * as Sentry from '@sentry/browser';
import Tracking from '~/tracking';
import { ASC } from '~/notes/constants';
import { __ } from '~/locale';
import { clearDraft } from '~/lib/utils/autosave';
import createNoteMutation from '../../graphql/notes/create_work_item_note.mutation.graphql';
import workItemByIidQuery from '../../graphql/work_item_by_iid.query.graphql';
import { TRACKING_CATEGORY_SHOW, i18n } from '../../constants';
import WorkItemNoteSignedOut from './work_item_note_signed_out.vue';
import WorkItemCommentLocked from './work_item_comment_locked.vue';
import WorkItemCommentForm from './work_item_comment_form.vue';

export default {
  constantOptions: {
    avatarUrl: window.gon.current_user_avatar_url,
  },
  components: {
    WorkItemNoteSignedOut,
    WorkItemCommentLocked,
    WorkItemCommentForm,
  },
  mixins: [Tracking.mixin()],
  inject: ['fullPath'],
  props: {
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    discussionId: {
      type: String,
      required: false,
      default: '',
    },
    autofocus: {
      type: Boolean,
      required: false,
      default: false,
    },
    addPadding: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemType: {
      type: String,
      required: true,
    },
    sortOrder: {
      type: String,
      required: false,
      default: ASC,
    },
    markdownPreviewPath: {
      type: String,
      required: true,
    },
    autocompleteDataSources: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isNewDiscussion: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      workItem: {},
      isEditing: this.isNewDiscussion,
      isSubmitting: false,
      isSubmittingWithKeydown: false,
    };
  },
  apollo: {
    workItem: {
      query: workItemByIidQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          iid: this.workItemIid,
        };
      },
      update(data) {
        return data.workspace.workItems.nodes[0];
      },
      skip() {
        return !this.workItemIid;
      },
      error() {
        this.$emit('error', i18n.fetchError);
      },
    },
  },
  computed: {
    signedIn() {
      return Boolean(window.gon.current_user_id);
    },
    autosaveKey() {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      return this.discussionId ? `${this.discussionId}-comment` : `${this.workItemId}-comment`;
    },
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_comment',
        property: `type_${this.workItemType}`,
      };
    },
    timelineEntryInnerClass() {
      return {
        'timeline-entry-inner': this.isNewDiscussion,
      };
    },
    timelineContentClass() {
      return {
        'timeline-content': true,
        'gl-border-0! gl-pl-0!': !this.addPadding,
      };
    },
    parentClass() {
      return {
        'gl-relative gl-display-flex gl-align-items-flex-start gl-flex-nowrap': !this.isEditing,
      };
    },
    isProjectArchived() {
      return this.workItem?.project?.archived;
    },
    canUpdate() {
      return this.workItem?.userPermissions?.updateWorkItem;
    },
    workItemState() {
      return this.workItem?.state;
    },
    commentButtonText() {
      return this.isNewDiscussion ? __('Comment') : __('Reply');
    },
    timelineEntryClass() {
      return {
        'timeline-entry note-form': this.isNewDiscussion,
        // eslint-disable-next-line @gitlab/require-i18n-strings
        'note note-wrapper note-comment discussion-reply-holder gl-border-t-0! clearfix': !this
          .isNewDiscussion,
        'gl-bg-white! gl-pt-0!': this.isEditing,
      };
    },
  },
  watch: {
    autofocus: {
      immediate: true,
      handler(focus) {
        if (focus) {
          this.isEditing = true;
        }
      },
    },
  },
  methods: {
    async updateWorkItem(commentText) {
      this.isSubmitting = true;
      this.$emit('replying', commentText);
      try {
        this.track('add_work_item_comment');

        await this.$apollo.mutate({
          mutation: createNoteMutation,
          variables: {
            input: {
              noteableId: this.workItemId,
              body: commentText,
              discussionId: this.discussionId || null,
            },
          },
          update(store, createNoteData) {
            const numErrors = createNoteData.data?.createNote?.errors?.length;

            if (numErrors) {
              const { errors } = createNoteData.data.createNote;

              // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/346557
              // When a note only contains quick actions,
              // additional "helpful" messages are embedded in the errors field.
              // For instance, a note solely composed of "/assign @foobar" would
              // return a message "Commands only Assigned @root." as an error on creation
              // even though the quick action successfully executed.
              if (
                numErrors === 2 &&
                errors[0].includes('Commands only') &&
                errors[1].includes('Command names')
              ) {
                return;
              }

              throw new Error(createNoteData.data?.createNote?.errors[0]);
            }
          },
        });
        /**
         * https://gitlab.com/gitlab-org/gitlab/-/issues/388314
         *
         * Once form is successfully submitted, emit replied event,
         * mark isSubmitting to false and clear storage before hiding the form.
         * This will restrict comment form to restore the value while textarea
         * input triggered due to keyboard event meta+enter.
         *
         */
        this.$emit('replied');
        clearDraft(this.autosaveKey);
        this.cancelEditing();
      } catch (error) {
        this.$emit('error', error.message);
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    cancelEditing() {
      this.isEditing = this.isNewDiscussion;
      this.$emit('cancelEditing');
    },
    showReplyForm() {
      this.isEditing = true;
      this.$emit('startReplying');
    },
  },
};
</script>

<template>
  <li :class="timelineEntryClass">
    <work-item-note-signed-out v-if="!signedIn" />
    <work-item-comment-locked
      v-else-if="!canUpdate"
      :work-item-type="workItemType"
      :is-project-archived="isProjectArchived"
    />
    <div v-else :class="timelineEntryInnerClass">
      <div :class="timelineContentClass">
        <div :class="parentClass">
          <work-item-comment-form
            v-if="isEditing"
            :work-item-type="workItemType"
            :aria-label="__('Add a reply')"
            :is-submitting="isSubmitting"
            :autosave-key="autosaveKey"
            :is-new-discussion="isNewDiscussion"
            :autocomplete-data-sources="autocompleteDataSources"
            :markdown-preview-path="markdownPreviewPath"
            :work-item-state="workItemState"
            :work-item-id="workItemId"
            :autofocus="autofocus"
            :comment-button-text="commentButtonText"
            @submitForm="updateWorkItem"
            @cancelEditing="cancelEditing"
          />
          <textarea
            v-else
            ref="textarea"
            rows="1"
            class="reply-placeholder-text-field gl-font-regular!"
            data-testid="note-reply-textarea"
            :placeholder="__('Reply')"
            :aria-label="__('Reply to comment')"
            @focus="showReplyForm"
            @click="showReplyForm"
          ></textarea>
        </div>
      </div>
    </div>
  </li>
</template>
