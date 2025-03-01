import $ from 'jquery';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import waitForPromises from 'helpers/wait_for_promises';
import blobBundle from '~/blob_edit/blob_bundle';

import SourceEditor from '~/blob_edit/edit_blob';
import { createAlert } from '~/alert';

jest.mock('~/blob_edit/edit_blob');
jest.mock('~/alert');

describe('BlobBundle', () => {
  beforeAll(() => {
    // HACK: Workaround readonly property in Jest
    Object.defineProperty(window, 'onbeforeunload', {
      writable: true,
    });
  });

  it('does not load SourceEditor by default', () => {
    blobBundle();
    expect(SourceEditor).not.toHaveBeenCalled();
  });

  it('loads SourceEditor for the edit screen', async () => {
    setHTMLFixture(`<div class="js-edit-blob-form"></div>`);
    blobBundle();
    await waitForPromises();
    expect(SourceEditor).toHaveBeenCalled();

    resetHTMLFixture();
  });

  describe('No Suggest Popover', () => {
    beforeEach(() => {
      setHTMLFixture(`
      <div class="js-edit-blob-form" data-blob-filename="blah">
        <button class="js-commit-button"></button>
        <button id='cancel-changes'></button>
      </div>`);

      blobBundle();
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('sets the window beforeunload listener to a function returning a string', () => {
      expect(window.onbeforeunload()).toBe('');
    });

    it('removes beforeunload listener if commit button is clicked', () => {
      $('.js-commit-button').click();

      expect(window.onbeforeunload).toBeNull();
    });

    it('removes beforeunload listener when cancel link is clicked', () => {
      $('#cancel-changes').click();

      expect(window.onbeforeunload).toBeNull();
    });
  });

  describe('Suggest Popover', () => {
    let trackingSpy;

    beforeEach(() => {
      setHTMLFixture(`
      <div class="js-edit-blob-form" data-blob-filename="blah" id="target">
        <div class="js-suggest-gitlab-ci-yml"
          data-target="#target"
          data-track-label="suggest_gitlab_ci_yml"
          data-dismiss-key="1"
          data-human-access="owner"
          data-merge-request-path="path/to/mr">
          <button id='commit-changes' class="js-commit-button"></button>
          <button id='cancel-changes'></button>
        </div>
      </div>`);

      trackingSpy = mockTracking('_category_', $('#commit-changes').element, jest.spyOn);
      document.body.dataset.page = 'projects:blob:new';

      blobBundle();
    });

    afterEach(() => {
      unmockTracking();
      resetHTMLFixture();
    });

    it('sends a tracking event when the commit button is clicked', () => {
      $('#commit-changes').click();

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, undefined, {
        label: 'suggest_gitlab_ci_yml',
        property: 'owner',
      });
    });
  });

  describe('Error handling', () => {
    let message;
    beforeEach(() => {
      setHTMLFixture(`<div class="js-edit-blob-form" data-blob-filename="blah"></div>`);
      message = 'Foo';
      SourceEditor.mockImplementation(() => {
        throw new Error(message);
      });
    });

    afterEach(() => {
      resetHTMLFixture();
      SourceEditor.mockClear();
    });

    it('correctly outputs error message when it occurs', async () => {
      blobBundle();
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith({ message });
    });
  });
});
