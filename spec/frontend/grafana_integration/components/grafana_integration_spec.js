import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { TEST_HOST } from 'helpers/test_constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import GrafanaIntegration from '~/grafana_integration/components/grafana_integration.vue';
import { createStore } from '~/grafana_integration/store';
import axios from '~/lib/utils/axios_utils';
import { refreshCurrentPage } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

describe('grafana integration component', () => {
  let wrapper;
  let store;
  const operationsSettingsEndpoint = `${TEST_HOST}/mock/ops/settings/endpoint`;
  const grafanaIntegrationUrl = `${TEST_HOST}`;
  const grafanaIntegrationToken = 'someToken';

  beforeEach(() => {
    store = createStore({
      operationsSettingsEndpoint,
      grafanaIntegrationUrl,
      grafanaIntegrationToken,
    });
  });

  afterEach(() => {
    createAlert.mockReset();
    refreshCurrentPage.mockReset();
  });

  describe('default state', () => {
    it('to match the default snapshot', () => {
      wrapper = shallowMount(GrafanaIntegration, { store });

      expect(wrapper.element).toMatchSnapshot();
    });
  });

  it('renders header text', () => {
    wrapper = shallowMount(GrafanaIntegration, { store });

    expect(wrapper.find('.js-section-header').text()).toBe('Grafana authentication');
  });

  describe('expand/collapse button', () => {
    it('renders as an expand button by default', () => {
      wrapper = shallowMount(GrafanaIntegration, { store });

      const button = wrapper.findComponent(GlButton);
      expect(button.text()).toBe('Expand');
    });
  });

  describe('sub-header', () => {
    it('renders descriptive text', () => {
      wrapper = shallowMount(GrafanaIntegration, { store });

      expect(wrapper.find('.js-section-sub-header').text()).toContain(
        'Set up Grafana authentication to embed Grafana panels in GitLab Flavored Markdown.\n      Learn more.',
      );
    });
  });

  describe('form', () => {
    beforeEach(() => {
      jest.spyOn(axios, 'patch').mockImplementation();
      wrapper = mountExtended(GrafanaIntegration, { store });
    });

    afterEach(() => {
      axios.patch.mockReset();
    });

    describe('submit button', () => {
      const findSubmitButton = () => wrapper.findByTestId('save-grafana-settings-button');

      const endpointRequest = [
        operationsSettingsEndpoint,
        {
          project: {
            grafana_integration_attributes: {
              grafana_url: grafanaIntegrationUrl,
              token: grafanaIntegrationToken,
              enabled: false,
            },
          },
        },
      ];

      it('submits form on click', async () => {
        axios.patch.mockResolvedValue();
        findSubmitButton(wrapper).trigger('click');

        expect(axios.patch).toHaveBeenCalledWith(...endpointRequest);
        await nextTick();
        expect(refreshCurrentPage).toHaveBeenCalled();
      });

      it('creates alert banner on error', async () => {
        const message = 'mockErrorMessage';
        axios.patch.mockRejectedValue({ response: { data: { message } } });

        findSubmitButton().trigger('click');

        expect(axios.patch).toHaveBeenCalledWith(...endpointRequest);

        await nextTick();
        await jest.runAllTicks();
        expect(createAlert).toHaveBeenCalledWith({
          message: `There was an error saving your changes. ${message}`,
        });
      });
    });
  });
});
