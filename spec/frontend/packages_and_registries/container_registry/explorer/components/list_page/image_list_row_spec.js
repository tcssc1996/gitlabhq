import { GlSprintf, GlSkeletonLoader, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { mockTracking } from 'helpers/tracking_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import DeleteButton from '~/packages_and_registries/container_registry/explorer/components/delete_button.vue';
import CleanupStatus from '~/packages_and_registries/container_registry/explorer/components/list_page/cleanup_status.vue';
import Component from '~/packages_and_registries/container_registry/explorer/components/list_page/image_list_row.vue';
import {
  ROW_SCHEDULED_FOR_DELETION,
  LIST_DELETE_BUTTON_DISABLED,
  REMOVE_REPOSITORY_LABEL,
  IMAGE_DELETE_SCHEDULED_STATUS,
  IMAGE_MIGRATING_STATE,
  SCHEDULED_STATUS,
  COPY_IMAGE_PATH_TITLE,
} from '~/packages_and_registries/container_registry/explorer/constants';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import ListItem from '~/vue_shared/components/registry/list_item.vue';
import { imagesListResponse } from '../../mock_data';
import { RouterLink } from '../../stubs';

describe('Image List Row', () => {
  let wrapper;
  const [item] = imagesListResponse;

  const findDetailsLink = () => wrapper.find('[data-testid="details-link"]');
  const findTagsCount = () => wrapper.find('[data-testid="tags-count"]');
  const findDeleteBtn = () => wrapper.findComponent(DeleteButton);
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findCleanupStatus = () => wrapper.findComponent(CleanupStatus);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findListItemComponent = () => wrapper.findComponent(ListItem);
  const findShowFullPathButton = () => wrapper.findComponent(GlButton);

  const mountComponent = (props) => {
    wrapper = shallowMount(Component, {
      stubs: {
        RouterLink,
        GlSprintf,
        ListItem,
        GlButton,
      },
      propsData: {
        item,
        ...props,
      },
      provide: {
        config: {},
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  describe('image title and path', () => {
    it('renders shortened name of image and contains a link to the details page', () => {
      mountComponent();

      const link = findDetailsLink();
      expect(link.text()).toBe('gitlab-test/rails-12009');

      expect(link.props('to')).toMatchObject({
        name: 'details',
        params: {
          id: getIdFromGraphQLId(item.id),
        },
      });

      expect(findShowFullPathButton().exists()).toBe(true);
    });

    it('when the image has no name lists the path', () => {
      mountComponent({ item: { ...item, name: '' } });

      expect(findDetailsLink().text()).toBe('gitlab-test');
    });

    it('clicking on shortened name of image hides the button & shows full path', async () => {
      mountComponent();

      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      const mockFocusFn = jest.fn();
      wrapper.vm.$refs.imageName.$el.focus = mockFocusFn;

      await findShowFullPathButton().trigger('click');

      expect(findShowFullPathButton().exists()).toBe(false);
      expect(findDetailsLink().text()).toBe(item.path);
      expect(mockFocusFn).toHaveBeenCalled();
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_show_full_path', {
        label: 'registry_image_list',
      });
    });

    it('contains a clipboard button', () => {
      mountComponent();
      const button = findClipboardButton();
      expect(button.exists()).toBe(true);
      expect(button.props('text')).toBe(item.location);
      expect(button.props('title')).toBe(COPY_IMAGE_PATH_TITLE);
    });

    describe('cleanup status component', () => {
      it.each`
        expirationPolicyCleanupStatus | shown
        ${null}                       | ${false}
        ${SCHEDULED_STATUS}           | ${true}
      `(
        'when expirationPolicyCleanupStatus is $expirationPolicyCleanupStatus it is $shown that the component exists',
        ({ expirationPolicyCleanupStatus, shown }) => {
          mountComponent({ item: { ...item, expirationPolicyCleanupStatus } });

          expect(findCleanupStatus().exists()).toBe(shown);

          if (shown) {
            expect(findCleanupStatus().props()).toMatchObject({
              status: expirationPolicyCleanupStatus,
            });
          }
        },
      );
    });

    describe('when the item is deleting', () => {
      beforeEach(() => {
        mountComponent({ item: { ...item, status: IMAGE_DELETE_SCHEDULED_STATUS } });
      });

      it('the router link does not exist', () => {
        expect(findDetailsLink().exists()).toBe(false);
      });

      it('image name exists', () => {
        expect(findListItemComponent().text()).toContain('gitlab-test/rails-12009');
      });

      it(`contains secondary text ${ROW_SCHEDULED_FOR_DELETION}`, () => {
        expect(findListItemComponent().text()).toContain(ROW_SCHEDULED_FOR_DELETION);
      });

      it('the tags count does not exist', () => {
        expect(findTagsCount().exists()).toBe(false);
      });

      it('the clipboard button is disabled', () => {
        expect(findClipboardButton().attributes('disabled')).toBeDefined();
      });
    });
  });

  describe('delete button', () => {
    it('exists', () => {
      mountComponent();
      expect(findDeleteBtn().exists()).toBe(true);
    });

    it('has the correct props', () => {
      mountComponent();

      expect(findDeleteBtn().props()).toMatchObject({
        title: REMOVE_REPOSITORY_LABEL,
        tooltipDisabled: item.canDelete,
        tooltipTitle: LIST_DELETE_BUTTON_DISABLED,
      });
    });

    it('emits a delete event', () => {
      mountComponent();

      findDeleteBtn().vm.$emit('delete');
      expect(wrapper.emitted('delete')).toEqual([[item]]);
    });

    it.each`
      canDelete | status                           | state
      ${false}  | ${''}                            | ${true}
      ${false}  | ${IMAGE_DELETE_SCHEDULED_STATUS} | ${true}
      ${true}   | ${IMAGE_DELETE_SCHEDULED_STATUS} | ${true}
      ${true}   | ${''}                            | ${false}
    `(
      'disabled is $state when canDelete is $canDelete and status is $status',
      ({ canDelete, status, state }) => {
        mountComponent({ item: { ...item, canDelete, status } });

        expect(findDeleteBtn().props('disabled')).toBe(state);
      },
    );

    it('is disabled when migrationState is importing', () => {
      mountComponent({ item: { ...item, migrationState: IMAGE_MIGRATING_STATE } });

      expect(findDeleteBtn().props('disabled')).toBe(true);
    });
  });

  describe('tags count', () => {
    it('exists', () => {
      mountComponent();
      expect(findTagsCount().exists()).toBe(true);
    });

    describe('loading state', () => {
      it('shows a loader when metadataLoading is true', () => {
        mountComponent({ metadataLoading: true });

        expect(findSkeletonLoader().exists()).toBe(true);
      });

      it('hides the tags count while loading', () => {
        mountComponent({ metadataLoading: true });

        expect(findTagsCount().exists()).toBe(false);
      });
    });

    describe('tags count text', () => {
      it('with one tag in the image', () => {
        mountComponent({ item: { ...item, tagsCount: 1 } });

        expect(findTagsCount().text()).toMatchInterpolatedText('1 tag');
      });
      it('with more than one tag in the image', () => {
        mountComponent({ item: { ...item, tagsCount: 3 } });

        expect(findTagsCount().text()).toMatchInterpolatedText('3 tags');
      });
    });
  });
});
