import { nextTick } from 'vue';
import { GlLink, GlForm } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import BubbleMenu from '~/content_editor/components/bubble_menus/bubble_menu.vue';
import MediaBubbleMenu from '~/content_editor/components/bubble_menus/media_bubble_menu.vue';
import { stubComponent } from 'helpers/stub_component';
import eventHubFactory from '~/helpers/event_hub_factory';
import Audio from '~/content_editor/extensions/audio';
import DrawioDiagram from '~/content_editor/extensions/drawio_diagram';
import Image from '~/content_editor/extensions/image';
import Video from '~/content_editor/extensions/video';
import {
  createTestEditor,
  emitEditorEvent,
  mockChainedCommands,
  createTransactionWithMeta,
} from '../../test_utils';
import {
  PROJECT_WIKI_ATTACHMENT_IMAGE_HTML,
  PROJECT_WIKI_ATTACHMENT_AUDIO_HTML,
  PROJECT_WIKI_ATTACHMENT_VIDEO_HTML,
  PROJECT_WIKI_ATTACHMENT_DRAWIO_DIAGRAM_HTML,
} from '../../test_constants';

const TIPTAP_AUDIO_HTML = `<p>
  <span class="media-container audio-container"><audio src="https://gitlab.com/favicon.png" controls="true" data-setup="{}" data-title="gitlab favicon"></audio><a href="https://gitlab.com/favicon.png" class="with-attachment-icon">gitlab favicon</a></span>
</p>`;

const TIPTAP_DIAGRAM_HTML = `<p>
  <img src="https://gitlab.com/favicon.png" alt="gitlab favicon" title="gitlab favicon">
</p>`;

const TIPTAP_IMAGE_HTML = `<p>
  <img src="https://gitlab.com/favicon.png" alt="gitlab favicon" title="gitlab favicon">
</p>`;

const TIPTAP_VIDEO_HTML = `<p>
  <span class="media-container video-container"><video src="https://gitlab.com/favicon.png" controls="true" data-setup="{}" data-title="gitlab favicon"></video><a href="https://gitlab.com/favicon.png" class="with-attachment-icon">gitlab favicon</a></span>
</p>`;

const createFakeEvent = () => ({ preventDefault: jest.fn(), stopPropagation: jest.fn() });

describe.each`
  mediaType          | mediaHTML                                      | filePath                  | mediaOutputHTML
  ${'image'}         | ${PROJECT_WIKI_ATTACHMENT_IMAGE_HTML}          | ${'test-file.png'}        | ${TIPTAP_IMAGE_HTML}
  ${'drawioDiagram'} | ${PROJECT_WIKI_ATTACHMENT_DRAWIO_DIAGRAM_HTML} | ${'test-file.drawio.svg'} | ${TIPTAP_DIAGRAM_HTML}
  ${'audio'}         | ${PROJECT_WIKI_ATTACHMENT_AUDIO_HTML}          | ${'test-file.mp3'}        | ${TIPTAP_AUDIO_HTML}
  ${'video'}         | ${PROJECT_WIKI_ATTACHMENT_VIDEO_HTML}          | ${'test-file.mp4'}        | ${TIPTAP_VIDEO_HTML}
`(
  'content_editor/components/bubble_menus/media_bubble_menu ($mediaType)',
  ({ mediaType, mediaHTML, filePath, mediaOutputHTML }) => {
    let wrapper;
    let tiptapEditor;
    let contentEditor;
    let eventHub;

    const buildEditor = () => {
      tiptapEditor = createTestEditor({ extensions: [Image, Audio, Video, DrawioDiagram] });
      contentEditor = { resolveUrl: jest.fn() };
      eventHub = eventHubFactory();
    };

    const buildWrapper = () => {
      wrapper = mountExtended(MediaBubbleMenu, {
        provide: {
          tiptapEditor,
          contentEditor,
          eventHub,
        },
        stubs: {
          BubbleMenu: stubComponent(BubbleMenu),
        },
      });
    };

    const findBubbleMenu = () => wrapper.findComponent(BubbleMenu);

    const showMenu = async () => {
      findBubbleMenu().vm.$emit('show');
      await emitEditorEvent({
        event: 'transaction',
        tiptapEditor,
        params: { transaction: createTransactionWithMeta() },
      });
      await nextTick();
    };

    const buildWrapperAndDisplayMenu = () => {
      buildWrapper();

      return showMenu();
    };

    const selectFile = async (file) => {
      const input = wrapper.findComponent({ ref: 'fileSelector' });

      // override the property definition because `input.files` isn't directly modifyable
      Object.defineProperty(input.element, 'files', { value: [file], writable: true });
      await input.trigger('change');
    };

    const expectLinkButtonsToExist = (exist = true) => {
      expect(wrapper.findComponent(GlLink).exists()).toBe(exist);
      expect(wrapper.findByTestId('copy-media-src').exists()).toBe(exist);
      expect(wrapper.findByTestId('edit-media').exists()).toBe(exist);
      expect(wrapper.findByTestId('delete-media').exists()).toBe(exist);
    };

    beforeEach(() => {
      buildEditor();

      tiptapEditor
        .chain()
        .insertContent(mediaHTML)
        .setNodeSelection(4) // select the media
        .run();

      contentEditor.resolveUrl.mockResolvedValue(`/group1/project1/-/wikis/${filePath}`);
    });

    it('renders bubble menu component', async () => {
      await buildWrapperAndDisplayMenu();

      expect(findBubbleMenu().classes()).toEqual(['gl-shadow', 'gl-rounded-base', 'gl-bg-white']);
    });

    it('shows a clickable link to the image', async () => {
      await buildWrapperAndDisplayMenu();

      const link = wrapper.findComponent(GlLink);
      expect(link.attributes()).toEqual(
        expect.objectContaining({
          href: `/group1/project1/-/wikis/${filePath}`,
          'aria-label': filePath,
          title: filePath,
          target: '_blank',
        }),
      );
      expect(link.text()).toBe(filePath);
    });

    it('shows a loading percentage for a file being uploaded', async () => {
      jest.spyOn(tiptapEditor, 'isActive').mockImplementation((name) => name === mediaType);

      await buildWrapperAndDisplayMenu();

      const setUploadProgress = async (progress) => {
        const transaction = createTransactionWithMeta('uploadProgress', {
          filename: filePath,
          progress,
        });
        await emitEditorEvent({ event: 'transaction', tiptapEditor, params: { transaction } });
      };

      tiptapEditor.chain().selectAll().updateAttributes(mediaType, { uploading: filePath }).run();

      await emitEditorEvent({ event: 'selectionUpdate', tiptapEditor });

      expect(wrapper.findComponent(GlLink).exists()).toBe(false);
      expect(wrapper.text()).toContain('Uploading: 0%');

      await setUploadProgress(0.4);

      expect(wrapper.text()).toContain('Uploading: 40%');

      await setUploadProgress(0.7);
      expect(wrapper.text()).toContain('Uploading: 70%');

      await setUploadProgress(1);
      expect(wrapper.text()).toContain('Uploading: 100%');
    });

    describe('when BubbleMenu emits hidden event', () => {
      it('resets media bubble menu state', async () => {
        await buildWrapperAndDisplayMenu();

        // Switch to edit mode to access component state in form fields
        await wrapper.findByTestId('edit-media').vm.$emit('click');

        const mediaSrcInput = wrapper.findByTestId('media-src').vm.$el;
        const mediaAltInput = wrapper.findByTestId('media-alt').vm.$el;

        expect(mediaSrcInput.value).not.toBe('');
        expect(mediaAltInput.value).not.toBe('');

        await wrapper.findComponent(BubbleMenu).vm.$emit('hidden');

        expect(mediaSrcInput.value).toBe('');
        expect(mediaAltInput.value).toBe('');
      });
    });

    describe('copy button', () => {
      it(`copies the canonical link to the ${mediaType} to clipboard`, async () => {
        await buildWrapperAndDisplayMenu();

        jest.spyOn(navigator.clipboard, 'writeText');

        await wrapper.findByTestId('copy-media-src').vm.$emit('click');

        expect(navigator.clipboard.writeText).toHaveBeenCalledWith(filePath);
      });
    });

    describe(`remove ${mediaType} button`, () => {
      it(`removes the ${mediaType}`, async () => {
        await buildWrapperAndDisplayMenu();

        await wrapper.findByTestId('delete-media').vm.$emit('click');

        expect(tiptapEditor.getHTML()).toBe('<p>\n  \n</p>');
      });
    });

    describe(`replace ${mediaType} button`, () => {
      beforeEach(buildWrapperAndDisplayMenu);

      if (mediaType !== 'drawioDiagram') {
        it('uploads and replaces the selected image when file input changes', async () => {
          const commands = mockChainedCommands(tiptapEditor, [
            'focus',
            'deleteSelection',
            'uploadAttachment',
            'run',
          ]);
          const file = new File(['foo'], 'foo.png', { type: 'image/png' });

          await wrapper.findByTestId('replace-media').vm.$emit('click');
          await selectFile(file);

          expect(commands.focus).toHaveBeenCalled();
          expect(commands.deleteSelection).toHaveBeenCalled();
          expect(commands.uploadAttachment).toHaveBeenCalledWith({ file });
          expect(commands.run).toHaveBeenCalled();
        });
      } else {
        // draw.io diagrams are replaced using the edit diagram button
        it('invokes editDiagram command', async () => {
          const commands = mockChainedCommands(tiptapEditor, [
            'focus',
            'createOrEditDiagram',
            'run',
          ]);
          await wrapper.findByTestId('edit-diagram').vm.$emit('click');

          expect(commands.focus).toHaveBeenCalled();
          expect(commands.createOrEditDiagram).toHaveBeenCalled();
          expect(commands.run).toHaveBeenCalled();
        });
      }
    });

    describe('edit button', () => {
      let mediaSrcInput;
      let mediaTitleInput;
      let mediaAltInput;

      beforeEach(async () => {
        await buildWrapperAndDisplayMenu();

        await wrapper.findByTestId('edit-media').vm.$emit('click');

        mediaSrcInput = wrapper.findByTestId('media-src');
        mediaTitleInput = wrapper.findByTestId('media-title');
        mediaAltInput = wrapper.findByTestId('media-alt');
      });

      it('hides the link and copy/edit/remove link buttons', () => {
        expectLinkButtonsToExist(false);
      });

      it(`shows a form to edit the ${mediaType} src/title/alt`, () => {
        expect(wrapper.findComponent(GlForm).exists()).toBe(true);

        expect(mediaSrcInput.element.value).toBe(filePath);
        expect(mediaTitleInput.element.value).toBe('');
        expect(mediaAltInput.element.value).toBe('test-file');
      });

      describe('after making changes in the form and clicking apply', () => {
        beforeEach(async () => {
          mediaSrcInput.setValue('https://gitlab.com/favicon.png');
          mediaAltInput.setValue('gitlab favicon');
          mediaTitleInput.setValue('gitlab favicon');

          contentEditor.resolveUrl.mockResolvedValue('https://gitlab.com/favicon.png');

          await wrapper.findComponent(GlForm).vm.$emit('submit', createFakeEvent());
        });

        it(`updates prosemirror doc with new src to the ${mediaType}`, () => {
          expect(tiptapEditor.getHTML()).toBe(mediaOutputHTML);
        });

        it(`updates the link to the ${mediaType} in the bubble menu`, () => {
          const link = wrapper.findComponent(GlLink);
          expect(link.attributes()).toEqual(
            expect.objectContaining({
              href: 'https://gitlab.com/favicon.png',
              'aria-label': 'https://gitlab.com/favicon.png',
              title: 'https://gitlab.com/favicon.png',
              target: '_blank',
            }),
          );
          expect(link.text()).toBe('https://gitlab.com/favicon.png');
        });
      });

      describe('after making changes in the form and clicking cancel', () => {
        beforeEach(async () => {
          mediaSrcInput.setValue('https://gitlab.com/favicon.png');
          mediaAltInput.setValue('gitlab favicon');
          mediaTitleInput.setValue('gitlab favicon');

          await wrapper.findByTestId('cancel-editing-media').vm.$emit('click');
        });

        it('hides the form and shows the copy/edit/remove link buttons', () => {
          expectLinkButtonsToExist();
        });

        it(`resets the form with old values of the ${mediaType} from prosemirror`, async () => {
          // click edit once again to show the form back
          await wrapper.findByTestId('edit-media').vm.$emit('click');

          mediaSrcInput = wrapper.findByTestId('media-src');
          mediaTitleInput = wrapper.findByTestId('media-title');
          mediaAltInput = wrapper.findByTestId('media-alt');

          expect(mediaSrcInput.element.value).toBe(filePath);
          expect(mediaAltInput.element.value).toBe('test-file');
          expect(mediaTitleInput.element.value).toBe('');
        });
      });
    });
  },
);
