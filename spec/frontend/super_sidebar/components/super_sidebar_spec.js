import { nextTick } from 'vue';
import { Mousetrap } from '~/lib/mousetrap';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SuperSidebar from '~/super_sidebar/components/super_sidebar.vue';
import HelpCenter from '~/super_sidebar/components/help_center.vue';
import UserBar from '~/super_sidebar/components/user_bar.vue';
import SidebarPeekBehavior, {
  STATE_CLOSED,
  STATE_WILL_OPEN,
  STATE_OPEN,
  STATE_WILL_CLOSE,
} from '~/super_sidebar/components/sidebar_peek_behavior.vue';
import SidebarPortalTarget from '~/super_sidebar/components/sidebar_portal_target.vue';
import ContextSwitcher from '~/super_sidebar/components/context_switcher.vue';
import SidebarMenu from '~/super_sidebar/components/sidebar_menu.vue';
import { sidebarState } from '~/super_sidebar/constants';
import {
  toggleSuperSidebarCollapsed,
  isCollapsed,
} from '~/super_sidebar/super_sidebar_collapsed_state_manager';
import { stubComponent } from 'helpers/stub_component';
import { sidebarData as mockSidebarData } from '../mock_data';

const initialSidebarState = { ...sidebarState };

jest.mock('~/super_sidebar/super_sidebar_collapsed_state_manager');
const closeContextSwitcherMock = jest.fn();

const trialStatusWidgetStubTestId = 'trial-status-widget';
const TrialStatusWidgetStub = { template: `<div data-testid="${trialStatusWidgetStubTestId}" />` };
const trialStatusPopoverStubTestId = 'trial-status-popover';
const TrialStatusPopoverStub = {
  template: `<div data-testid="${trialStatusPopoverStubTestId}" />`,
};

const peekClass = 'super-sidebar-peek';
const peekHintClass = 'super-sidebar-peek-hint';

describe('SuperSidebar component', () => {
  let wrapper;

  const findSidebar = () => wrapper.findByTestId('super-sidebar');
  const findUserBar = () => wrapper.findComponent(UserBar);
  const findContextSwitcher = () => wrapper.findComponent(ContextSwitcher);
  const findNavContainer = () => wrapper.findByTestId('nav-container');
  const findHelpCenter = () => wrapper.findComponent(HelpCenter);
  const findSidebarPortalTarget = () => wrapper.findComponent(SidebarPortalTarget);
  const findPeekBehavior = () => wrapper.findComponent(SidebarPeekBehavior);
  const findTrialStatusWidget = () => wrapper.findByTestId(trialStatusWidgetStubTestId);
  const findTrialStatusPopover = () => wrapper.findByTestId(trialStatusPopoverStubTestId);
  const findSidebarMenu = () => wrapper.findComponent(SidebarMenu);

  const createWrapper = ({
    provide = {},
    sidebarData = mockSidebarData,
    sidebarState: state = {},
  } = {}) => {
    Object.assign(sidebarState, state);

    wrapper = shallowMountExtended(SuperSidebar, {
      provide: {
        showTrialStatusWidget: false,
        ...provide,
      },
      propsData: {
        sidebarData,
      },
      stubs: {
        ContextSwitcher: stubComponent(ContextSwitcher, {
          methods: { close: closeContextSwitcherMock },
        }),
        TrialStatusWidget: TrialStatusWidgetStub,
        TrialStatusPopover: TrialStatusPopoverStub,
      },
    });
  };

  beforeEach(() => {
    Object.assign(sidebarState, initialSidebarState);
  });

  describe('default', () => {
    it('adds inert attribute when collapsed', () => {
      createWrapper({ sidebarState: { isCollapsed: true } });
      expect(findSidebar().attributes('inert')).toBe('inert');
    });

    it('does not add inert attribute when expanded', () => {
      createWrapper();
      expect(findSidebar().attributes('inert')).toBe(undefined);
    });

    it('renders UserBar with sidebarData', () => {
      createWrapper();
      expect(findUserBar().props('sidebarData')).toBe(mockSidebarData);
    });

    it('renders HelpCenter with sidebarData', () => {
      createWrapper();
      expect(findHelpCenter().props('sidebarData')).toBe(mockSidebarData);
    });

    it('does not render SidebarMenu when items are empty', () => {
      createWrapper();
      expect(findSidebarMenu().exists()).toBe(false);
    });

    it('renders SidebarMenu with menu items', () => {
      const menuItems = [
        { id: 1, title: 'Menu item 1' },
        { id: 2, title: 'Menu item 2' },
      ];
      createWrapper({ sidebarData: { ...mockSidebarData, current_menu_items: menuItems } });
      expect(findSidebarMenu().props('items')).toBe(menuItems);
    });

    it('renders SidebarPortalTarget', () => {
      createWrapper();
      expect(findSidebarPortalTarget().exists()).toBe(true);
    });

    it("does not call the context switcher's close method initially", () => {
      createWrapper();

      expect(closeContextSwitcherMock).not.toHaveBeenCalled();
    });

    it('renders hidden shortcut links', () => {
      createWrapper();
      const [linkAttrs] = mockSidebarData.shortcut_links;
      const link = wrapper.find(`.${linkAttrs.css_class}`);

      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(linkAttrs.href);
      expect(link.attributes('class')).toContain('gl-display-none');
    });

    it('sets up the sidebar toggle shortcut', () => {
      createWrapper();

      isCollapsed.mockReturnValue(false);
      Mousetrap.trigger('mod+\\');

      expect(toggleSuperSidebarCollapsed).toHaveBeenCalledTimes(1);
      expect(toggleSuperSidebarCollapsed).toHaveBeenCalledWith(true, true);

      isCollapsed.mockReturnValue(true);
      Mousetrap.trigger('mod+\\');

      expect(toggleSuperSidebarCollapsed).toHaveBeenCalledTimes(2);
      expect(toggleSuperSidebarCollapsed).toHaveBeenCalledWith(false, true);

      jest.spyOn(Mousetrap, 'unbind');

      wrapper.destroy();

      expect(Mousetrap.unbind).toHaveBeenCalledWith(['mod+\\']);
    });

    it('does not render trial status widget', () => {
      createWrapper();

      expect(findTrialStatusWidget().exists()).toBe(false);
      expect(findTrialStatusPopover().exists()).toBe(false);
    });

    it('does not have peek behavior', () => {
      createWrapper();

      expect(findPeekBehavior().exists()).toBe(false);
    });
  });

  describe('on collapse', () => {
    beforeEach(() => {
      createWrapper();
      sidebarState.isCollapsed = true;
    });

    it('closes the context switcher', () => {
      expect(closeContextSwitcherMock).toHaveBeenCalled();
    });
  });

  describe('peek behavior', () => {
    it(`initially makes sidebar inert and peekable (${STATE_CLOSED})`, () => {
      createWrapper({ sidebarState: { isCollapsed: true, isPeekable: true } });

      expect(findSidebar().attributes('inert')).toBe('inert');
      expect(findSidebar().classes()).not.toContain(peekHintClass);
      expect(findSidebar().classes()).not.toContain(peekClass);
    });

    it(`makes sidebar inert and shows peek hint when peek state is ${STATE_WILL_OPEN}`, async () => {
      createWrapper({ sidebarState: { isCollapsed: true, isPeekable: true } });

      findPeekBehavior().vm.$emit('change', STATE_WILL_OPEN);
      await nextTick();

      expect(findSidebar().attributes('inert')).toBe('inert');
      expect(findSidebar().classes()).toContain(peekHintClass);
      expect(findSidebar().classes()).not.toContain(peekClass);
    });

    it.each([STATE_OPEN, STATE_WILL_CLOSE])(
      'makes sidebar interactive and visible when peek state is %s',
      async (state) => {
        createWrapper({ sidebarState: { isCollapsed: true, isPeekable: true } });

        findPeekBehavior().vm.$emit('change', state);
        await nextTick();

        expect(findSidebar().attributes('inert')).toBe(undefined);
        expect(findSidebar().classes()).toContain(peekClass);
        expect(findSidebar().classes()).not.toContain(peekHintClass);
      },
    );
  });

  describe('nav container', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('allows overflow while the context switcher is closed', () => {
      expect(findNavContainer().classes()).toContain('gl-overflow-auto');
    });

    it('hides overflow when context switcher is opened', async () => {
      findContextSwitcher().vm.$emit('toggle', true);
      await nextTick();

      expect(findNavContainer().classes()).not.toContain('gl-overflow-auto');
    });
  });

  describe('when a trial is active', () => {
    beforeEach(() => {
      createWrapper({ provide: { showTrialStatusWidget: true } });
    });

    it('renders trial status widget', () => {
      expect(findTrialStatusWidget().exists()).toBe(true);
      expect(findTrialStatusPopover().exists()).toBe(true);
    });
  });
});
