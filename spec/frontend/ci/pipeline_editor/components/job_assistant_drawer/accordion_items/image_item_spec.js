import ImageItem from '~/ci/pipeline_editor/components/job_assistant_drawer/accordion_items/image_item.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { JOB_TEMPLATE } from '~/ci/pipeline_editor/components/job_assistant_drawer/constants';

describe('Image item', () => {
  let wrapper;

  const findImageNameInput = () => wrapper.findByTestId('image-name-input');
  const findImageEntrypointInput = () => wrapper.findByTestId('image-entrypoint-input');

  const dummyImageName = 'a';
  const dummyImageEntrypoint = ['b', 'c'];

  const createComponent = ({ job = JSON.parse(JSON.stringify(JOB_TEMPLATE)) } = {}) => {
    wrapper = shallowMountExtended(ImageItem, {
      propsData: {
        job,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('should emit update job event when filling inputs', () => {
    expect(wrapper.emitted('update-job')).toBeUndefined();

    findImageNameInput().vm.$emit('input', dummyImageName);

    expect(wrapper.emitted('update-job')).toHaveLength(1);
    expect(wrapper.emitted('update-job')[0]).toEqual(['image.name', dummyImageName]);

    findImageEntrypointInput().vm.$emit('input', dummyImageEntrypoint.join('\n'));

    expect(wrapper.emitted('update-job')).toHaveLength(2);
    expect(wrapper.emitted('update-job')[1]).toEqual(['image.entrypoint', dummyImageEntrypoint]);
  });
});
