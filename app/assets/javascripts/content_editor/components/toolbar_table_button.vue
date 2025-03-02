<script>
import { GlDisclosureDropdown, GlButton, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { clamp } from '../services/utils';

export const tableContentType = 'table';

const MIN_ROWS = 5;
const MIN_COLS = 5;
const MAX_ROWS = 10;
const MAX_COLS = 10;

export default {
  components: {
    GlButton,
    GlDisclosureDropdown,
  },
  directives: {
    GlTooltip,
  },
  inject: ['tiptapEditor'],
  data() {
    return {
      maxRows: MIN_ROWS,
      maxCols: MIN_COLS,
      rows: 1,
      cols: 1,
    };
  },
  methods: {
    list(n) {
      return new Array(n).fill().map((_, i) => i + 1);
    },
    setRowsAndCols(rows, cols) {
      this.rows = rows;
      this.cols = cols;
      this.maxRows = clamp(rows + 1, MIN_ROWS, MAX_ROWS);
      this.maxCols = clamp(cols + 1, MIN_COLS, MAX_COLS);
    },
    resetState() {
      this.rows = 1;
      this.cols = 1;
    },
    insertTable() {
      this.tiptapEditor
        .chain()
        .focus()
        .insertTable({
          rows: this.rows,
          cols: this.cols,
          withHeaderRow: true,
        })
        .run();

      this.resetState();
      this.$refs.dropdown.close();

      this.$emit('execute', { contentType: 'table' });
    },
    getButtonLabel(rows, cols) {
      return sprintf(__('Insert a %{rows}×%{cols} table'), { rows, cols });
    },
    onKeydown(key) {
      const delta = {
        ArrowUp: { rows: -1, cols: 0 },
        ArrowDown: { rows: 1, cols: 0 },
        ArrowLeft: { rows: 0, cols: -1 },
        ArrowRight: { rows: 0, cols: 1 },
      }[key] || { rows: 0, cols: 0 };

      const rows = clamp(this.rows + delta.rows, 1, this.maxRows);
      const cols = clamp(this.cols + delta.cols, 1, this.maxCols);

      this.setRowsAndCols(rows, cols);
    },
    setFocus(row, col) {
      this.$refs[`table-${row}-${col}`][0].$el.focus();
    },
  },
  MAX_COLS,
  MAX_ROWS,
  popperOptions: {
    strategy: 'fixed',
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    ref="dropdown"
    v-gl-tooltip
    size="small"
    category="tertiary"
    icon="table"
    :aria-label="__('Insert table')"
    :toggle-text="__('Insert table')"
    :popper-opts="$options.popperOptions"
    class="content-editor-table-dropdown"
    text-sr-only
    :fluid-width="true"
    @shown="setFocus(1, 1)"
  >
    <div
      class="gl-p-3 gl-pt-2"
      role="grid"
      :aria-colcount="$options.MAX_COLS"
      :aria-rowcount="$options.MAX_ROWS"
    >
      <div v-for="r of list(maxRows)" :key="r" class="gl-display-flex" role="row">
        <div v-for="c of list(maxCols)" :key="c" role="gridcell">
          <gl-button
            :ref="`table-${r}-${c}`"
            :class="{ 'active gl-bg-blue-50!': r <= rows && c <= cols }"
            :aria-label="getButtonLabel(r, c)"
            class="table-creator-grid-item gl-display-inline gl-rounded-0! gl-w-6! gl-h-6! gl-p-0!"
            @mouseover="setRowsAndCols(r, c)"
            @focus="setRowsAndCols(r, c)"
            @click="insertTable()"
            @keydown="onKeydown($event.key)"
          />
        </div>
      </div>
    </div>
    <div class="gl-border-t gl-px-4 gl-pt-3 gl-pb-2">
      {{ getButtonLabel(rows, cols) }}
    </div>
  </gl-disclosure-dropdown>
</template>
