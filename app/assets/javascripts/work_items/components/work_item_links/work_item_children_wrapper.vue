<script>
import produce from 'immer';
import Draggable from 'vuedraggable';

import { isLoggedIn } from '~/lib/utils/common_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { defaultSortableOptions } from '~/sortable/constants';

import { WORK_ITEM_TYPE_VALUE_OBJECTIVE } from '../../constants';
import { findHierarchyWidgets } from '../../utils';
import workItemByIidQuery from '../../graphql/work_item_by_iid.query.graphql';
import reorderWorkItem from '../../graphql/reorder_work_item.mutation.graphql';
import WorkItemLinkChild from './work_item_link_child.vue';

export default {
  components: {
    WorkItemLinkChild,
  },
  inject: ['fullPath'],
  props: {
    workItemType: {
      type: String,
      required: false,
      default: '',
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: null,
    },
    children: {
      type: Array,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      prefetchedWorkItem: null,
    };
  },
  computed: {
    canReorder() {
      return isLoggedIn() && this.canUpdate;
    },
    treeRootWrapper() {
      return this.canReorder ? Draggable : 'div';
    },
    treeRootOptions() {
      const options = {
        ...defaultSortableOptions,
        fallbackOnBody: false,
        group: 'sortable-container',
        tag: 'div',
        'ghost-class': 'tree-item-drag-active',
        'data-parent-id': this.workItemId,
        value: this.children,
      };

      return this.canReorder ? options : {};
    },
    hasIndirectChildren() {
      return this.children
        .map((child) => findHierarchyWidgets(child.widgets) || {})
        .some((hierarchy) => hierarchy.hasChildren);
    },
  },
  methods: {
    addWorkItemQuery({ iid }) {
      this.$apollo.addSmartQuery('prefetchedWorkItem', {
        query: workItemByIidQuery,
        variables: {
          fullPath: this.fullPath,
          iid,
        },
        update(data) {
          return data.workspace.workItems.nodes[0];
        },
        context: {
          isSingleRequest: true,
        },
      });
    },
    prefetchWorkItem({ iid }) {
      if (this.workItemType !== WORK_ITEM_TYPE_VALUE_OBJECTIVE) {
        this.prefetch = setTimeout(
          () => this.addWorkItemQuery({ iid }),
          DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
        );
      }
    },
    clearPrefetching() {
      if (this.prefetch) {
        clearTimeout(this.prefetch);
      }
    },
    getReorderParams({ oldIndex, newIndex }) {
      let relativePosition;

      // adjacentWorkItemId is always the item that's at the position
      // where target was moved.
      const adjacentWorkItemId = this.children[newIndex].id;

      if (newIndex === 0) {
        // If newIndex is `0`, item was moved to the top.
        // Adjacent reference will be the one which is currently at the top,
        // and it's relative position with respect to target's new position is `BEFORE`.
        relativePosition = 'BEFORE';
      } else if (newIndex === this.children.length - 1) {
        // If newIndex is last position in list, item was moved to the bottom.
        // Adjacent reference will be the one which is currently at the bottom,
        // and it's relative position with respect to target's new position is `AFTER`.
        relativePosition = 'AFTER';
      } else if (oldIndex < newIndex) {
        // If newIndex is neither top nor bottom, it was moved somewhere in the middle.
        // Adjacent reference will be the one which is currently at that position,

        // when the item is moved down, the newIndex is after the adjacent reference.
        relativePosition = 'AFTER';
      } else {
        // when the item is moved up, the newIndex is before the adjacent reference.
        relativePosition = 'BEFORE';
      }

      return {
        relativePosition,
        adjacentWorkItemId,
      };
    },
    handleDragOnEnd(params) {
      const { oldIndex, newIndex } = params;

      if (oldIndex === newIndex) return;

      const targetItem = this.children[oldIndex];

      const updatedChildren = this.children.slice();
      updatedChildren.splice(oldIndex, 1);
      updatedChildren.splice(newIndex, 0, targetItem);

      this.$apollo
        .mutate({
          mutation: reorderWorkItem,
          variables: {
            input: {
              id: targetItem.id,
              hierarchyWidget: this.getReorderParams({ oldIndex, newIndex }),
            },
          },
          update: (store) => {
            store.updateQuery(
              {
                query: workItemByIidQuery,
                variables: { fullPath: this.fullPath, iid: this.workItemIid },
              },
              (sourceData) =>
                produce(sourceData, (draftData) => {
                  const { widgets } = draftData.workspace.workItems.nodes[0];
                  const hierarchyWidget = findHierarchyWidgets(widgets);
                  hierarchyWidget.children.nodes = updatedChildren;
                }),
            );
          },
          optimisticResponse: {
            workItemUpdate: {
              __typename: 'WorkItemUpdatePayload',
              errors: [],
            },
          },
        })
        .then(
          ({
            data: {
              workItemUpdate: { errors },
            },
          }) => {
            if (errors?.length) {
              throw new Error(errors[0]);
            }
          },
        )
        .catch((error) => {
          this.updateError = error.message;
        });
    },
  },
};
</script>

<template>
  <component
    :is="treeRootWrapper"
    v-bind="treeRootOptions"
    :class="{ 'gl-cursor-grab sortable-container': canReorder }"
    @end="handleDragOnEnd"
  >
    <work-item-link-child
      v-for="child in children"
      :key="child.id"
      :can-update="canUpdate"
      :issuable-gid="workItemId"
      :child-item="child"
      :confidential="child.confidential"
      :work-item-type="workItemType"
      :has-indirect-children="hasIndirectChildren"
      @mouseover="prefetchWorkItem(child)"
      @mouseout="clearPrefetching"
      @removeChild="$emit('removeChild', $event)"
      @click="$emit('show-modal', { event: $event, child: $event.childItem || child })"
    />
  </component>
</template>
