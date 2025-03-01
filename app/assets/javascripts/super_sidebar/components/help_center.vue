<script>
import {
  GlBadge,
  GlButton,
  GlIcon,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
} from '@gitlab/ui';
import GitlabVersionCheckBadge from '~/gitlab_version_check/components/gitlab_version_check_badge.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import { FORUM_URL, DOCS_URL, PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import { STORAGE_KEY } from '~/whats_new/utils/notification';
import Tracking from '~/tracking';
import { DROPDOWN_Y_OFFSET, HELP_MENU_TRACKING_DEFAULTS, helpCenterState } from '../constants';

// Left offset required for the dropdown to be aligned with the super sidebar
const DROPDOWN_X_OFFSET = -4;

export default {
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GitlabVersionCheckBadge,
  },
  mixins: [Tracking.mixin({ property: 'nav_help_menu' })],
  i18n: {
    help: __('Help'),
    support: __('Support'),
    docs: __('GitLab documentation'),
    plans: __('Compare GitLab plans'),
    forum: __('Community forum'),
    contribute: __('Contribute to GitLab'),
    feedback: __('Provide feedback'),
    shortcuts: __('Keyboard shortcuts'),
    version: __('Your GitLab version'),
    whatsnew: __("What's new"),
    chat: s__('TanukiBot|Ask GitLab Chat'),
  },
  props: {
    sidebarData: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      showWhatsNewNotification: this.shouldShowWhatsNewNotification(),
      helpCenterState,
    };
  },
  computed: {
    itemGroups() {
      return {
        versionCheck: {
          items: [
            {
              text: this.$options.i18n.version,
              href: helpPagePath('update/index'),
              version: `${this.sidebarData.gitlab_version.major}.${this.sidebarData.gitlab_version.minor}`,
              extraAttrs: {
                ...this.trackingAttrs('version_help_dropdown'),
              },
            },
          ],
        },
        helpLinks: {
          items: [
            this.sidebarData.show_tanuki_bot && {
              icon: 'tanuki',
              text: this.$options.i18n.chat,
              action: this.showTanukiBotChat,
              extraAttrs: {
                ...this.trackingAttrs('tanuki_bot_help_dropdown'),
              },
            },
            {
              text: this.$options.i18n.help,
              href: helpPagePath(),
              extraAttrs: {
                ...this.trackingAttrs('help'),
              },
            },
            {
              text: this.$options.i18n.support,
              href: this.sidebarData.support_path,
              extraAttrs: {
                ...this.trackingAttrs('support'),
              },
            },
            {
              text: this.$options.i18n.docs,
              href: DOCS_URL,
              extraAttrs: {
                ...this.trackingAttrs('gitlab_documentation'),
              },
            },
            {
              text: this.$options.i18n.plans,
              href: `${PROMO_URL}/pricing`,
              extraAttrs: {
                ...this.trackingAttrs('compare_gitlab_plans'),
              },
            },
            {
              text: this.$options.i18n.forum,
              href: FORUM_URL,
              extraAttrs: {
                ...this.trackingAttrs('community_forum'),
              },
            },
            {
              text: this.$options.i18n.contribute,
              href: helpPagePath('', { anchor: 'contributing-to-gitlab' }),
              extraAttrs: {
                ...this.trackingAttrs('contribute_to_gitlab'),
              },
            },
            {
              text: this.$options.i18n.feedback,
              href: `${PROMO_URL}/submit-feedback`,
              extraAttrs: {
                ...this.trackingAttrs('submit_feedback'),
              },
            },
          ].filter(Boolean),
        },
        helpActions: {
          items: [
            {
              text: this.$options.i18n.shortcuts,
              action: this.showKeyboardShortcuts,
              extraAttrs: {
                class: 'js-shortcuts-modal-trigger',
                'data-track-action': 'click_button',
                'data-track-label': 'keyboard_shortcuts_help',
                'data-track-property': HELP_MENU_TRACKING_DEFAULTS['data-track-property'],
              },
              shortcut: '?',
            },
            this.sidebarData.display_whats_new && {
              text: this.$options.i18n.whatsnew,
              action: this.showWhatsNew,
              count:
                this.showWhatsNewNotification &&
                this.sidebarData.whats_new_most_recent_release_items_count,
              extraAttrs: {
                'data-track-action': 'click_button',
                'data-track-label': 'whats_new',
                'data-track-property': HELP_MENU_TRACKING_DEFAULTS['data-track-property'],
              },
            },
          ].filter(Boolean),
        },
      };
    },
    updateSeverity() {
      return this.sidebarData.gitlab_version_check?.severity;
    },
  },
  methods: {
    shouldShowWhatsNewNotification() {
      if (
        !this.sidebarData.display_whats_new ||
        localStorage.getItem(STORAGE_KEY) === this.sidebarData.whats_new_version_digest
      ) {
        return false;
      }
      return true;
    },

    showKeyboardShortcuts() {
      this.$refs.dropdown.close();
    },

    showTanukiBotChat() {
      this.$refs.dropdown.close();

      this.helpCenterState.showTanukiBotChatDrawer = true;
    },

    async showWhatsNew() {
      this.$refs.dropdown.close();
      this.showWhatsNewNotification = false;

      if (!this.toggleWhatsNewDrawer) {
        const appEl = document.getElementById('whats-new-app');
        const { default: toggleWhatsNewDrawer } = await import(
          /* webpackChunkName: 'whatsNewApp' */ '~/whats_new'
        );
        this.toggleWhatsNewDrawer = toggleWhatsNewDrawer;
        this.toggleWhatsNewDrawer(appEl);
      } else {
        this.toggleWhatsNewDrawer();
      }
    },

    trackingAttrs(label) {
      return {
        ...HELP_MENU_TRACKING_DEFAULTS,
        'data-track-label': label,
      };
    },

    trackDropdownToggle(show) {
      this.track('click_toggle', {
        label: show ? 'show_help_dropdown' : 'hide_help_dropdown',
      });
    },
  },
  popperOptions: {
    modifiers: [
      {
        name: 'offset',
        options: {
          offset: [DROPDOWN_X_OFFSET, DROPDOWN_Y_OFFSET],
        },
      },
    ],
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    ref="dropdown"
    :popper-options="$options.popperOptions"
    @shown="trackDropdownToggle(true)"
    @hidden="trackDropdownToggle(false)"
  >
    <template #toggle>
      <gl-button category="tertiary" icon="question-o" class="btn-with-notification">
        <span v-if="showWhatsNewNotification" class="notification-dot-info"></span>
        {{ $options.i18n.help }}
      </gl-button>
    </template>

    <gl-disclosure-dropdown-group
      v-if="sidebarData.show_version_check"
      :group="itemGroups.versionCheck"
    >
      <template #list-item="{ item }">
        <span class="gl-display-flex gl-flex-direction-column gl-line-height-24">
          <span class="gl-font-sm gl-font-weight-bold">
            {{ item.text }}
            <gl-emoji data-name="rocket" />
          </span>
          <span>
            <span class="gl-mr-2">{{ item.version }}</span>
            <gitlab-version-check-badge v-if="updateSeverity" :status="updateSeverity" size="sm" />
          </span>
        </span>
      </template>
    </gl-disclosure-dropdown-group>

    <gl-disclosure-dropdown-group
      :group="itemGroups.helpLinks"
      :bordered="sidebarData.show_version_check"
    >
      <template #list-item="{ item }">
        <span class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
          {{ item.text }}
          <gl-icon v-if="item.icon" :name="item.icon" class="gl-text-orange-500" />
        </span>
      </template>
    </gl-disclosure-dropdown-group>

    <gl-disclosure-dropdown-group :group="itemGroups.helpActions" bordered>
      <template #list-item="{ item }">
        <span
          class="gl-display-flex gl-justify-content-space-between gl-align-items-center gl-my-n1"
        >
          {{ item.text }}
          <gl-badge v-if="item.count" pill size="sm" variant="info">{{ item.count }}</gl-badge>
          <kbd v-else-if="item.shortcut" class="flat">?</kbd>
        </span>
      </template>
    </gl-disclosure-dropdown-group>
  </gl-disclosure-dropdown>
</template>
