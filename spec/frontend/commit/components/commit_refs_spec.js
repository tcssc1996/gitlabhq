import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import commitReferences from '~/projects/commit_box/info/graphql/queries/commit_references.query.graphql';
import containingBranchesQuery from '~/projects/commit_box/info/graphql/queries/commit_containing_branches.query.graphql';
import RefsList from '~/projects/commit_box/info/components/refs_list.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  FETCH_CONTAINING_REFS_EVENT,
  FETCH_COMMIT_REFERENCES_ERROR,
} from '~/projects/commit_box/info/constants';
import CommitRefs from '~/projects/commit_box/info/components/commit_refs.vue';

import {
  mockCommitReferencesResponse,
  mockOnlyBranchesResponse,
  mockContainingBranchesResponse,
  refsListPropsMock,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Commit references component', () => {
  let wrapper;

  const successQueryHandler = (mockResponse) => jest.fn().mockResolvedValue(mockResponse);
  const failedQueryHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));
  const containingBranchesQueryHandler = successQueryHandler(mockContainingBranchesResponse);
  const findRefsLists = () => wrapper.findAllComponents(RefsList);
  const branchesList = () => findRefsLists().at(0);

  const createComponent = async (
    commitReferencesQueryHandler = successQueryHandler(mockCommitReferencesResponse),
  ) => {
    wrapper = shallowMount(CommitRefs, {
      apolloProvider: createMockApollo([
        [commitReferences, commitReferencesQueryHandler],
        [containingBranchesQuery, containingBranchesQueryHandler],
      ]),
      provide: {
        fullPath: '/some/project',
        commitSha: 'xxx',
      },
    });

    await waitForPromises();
  };

  it('renders component correcrly', async () => {
    await createComponent();
    expect(findRefsLists()).toHaveLength(2);
  });

  it('passes props to refs list', async () => {
    await createComponent();
    expect(branchesList().props()).toEqual(refsListPropsMock);
  });

  it('shows alert when response fails', async () => {
    await createComponent(failedQueryHandler);
    expect(createAlert).toHaveBeenCalledWith({
      message: FETCH_COMMIT_REFERENCES_ERROR,
      captureError: true,
    });
  });

  it('fetches containing refs on the fetch event', async () => {
    await createComponent();
    branchesList().vm.$emit(FETCH_CONTAINING_REFS_EVENT);
    await waitForPromises();
    expect(containingBranchesQueryHandler).toHaveBeenCalledTimes(1);
  });

  it('does not render list when there is no branches or tags', async () => {
    await createComponent(successQueryHandler(mockOnlyBranchesResponse));
    expect(findRefsLists()).toHaveLength(1);
  });
});
