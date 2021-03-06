import Api from '~/api';
import createFlash from '~/flash';
import { visitUrl, setUrlParams } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { GROUPS_LOCAL_STORAGE_KEY, PROJECTS_LOCAL_STORAGE_KEY } from './constants';
import * as types from './mutation_types';
import { loadDataFromLS, setFrequentItemToLS, mergeById } from './utils';

export const fetchGroups = ({ commit }, search) => {
  commit(types.REQUEST_GROUPS);
  Api.groups(search, { order_by: 'similarity' })
    .then((data) => {
      commit(types.RECEIVE_GROUPS_SUCCESS, data);
    })
    .catch(() => {
      createFlash({ message: __('There was a problem fetching groups.') });
      commit(types.RECEIVE_GROUPS_ERROR);
    });
};

export const fetchProjects = ({ commit, state }, search) => {
  commit(types.REQUEST_PROJECTS);
  const groupId = state.query?.group_id;
  const callback = (data) => {
    if (data) {
      commit(types.RECEIVE_PROJECTS_SUCCESS, data);
    } else {
      createFlash({ message: __('There was an error fetching projects') });
      commit(types.RECEIVE_PROJECTS_ERROR);
    }
  };

  if (groupId) {
    // TODO (https://gitlab.com/gitlab-org/gitlab/-/issues/323331): For errors `createFlash` is called twice; in `callback` and in `Api.groupProjects`
    Api.groupProjects(
      groupId,
      search,
      { order_by: 'similarity', with_shared: false, include_subgroups: true },
      callback,
    );
  } else {
    // The .catch() is due to the API method not handling a rejection properly
    Api.projects(search, { order_by: 'similarity' }, callback).catch(() => {
      callback();
    });
  }
};

export const preloadStoredFrequentItems = ({ commit }) => {
  const storedGroups = loadDataFromLS(GROUPS_LOCAL_STORAGE_KEY);
  commit(types.LOAD_FREQUENT_ITEMS, { key: GROUPS_LOCAL_STORAGE_KEY, data: storedGroups });

  const storedProjects = loadDataFromLS(PROJECTS_LOCAL_STORAGE_KEY);
  commit(types.LOAD_FREQUENT_ITEMS, { key: PROJECTS_LOCAL_STORAGE_KEY, data: storedProjects });
};

export const loadFrequentGroups = async ({ commit, state }) => {
  const storedData = state.frequentItems[GROUPS_LOCAL_STORAGE_KEY];
  const promises = storedData.map((d) => Api.group(d.id));
  try {
    const inflatedData = mergeById(await Promise.all(promises), storedData);
    commit(types.LOAD_FREQUENT_ITEMS, { key: GROUPS_LOCAL_STORAGE_KEY, data: inflatedData });
  } catch {
    createFlash({ message: __('There was a problem fetching recent groups.') });
  }
};

export const loadFrequentProjects = async ({ commit, state }) => {
  const storedData = state.frequentItems[PROJECTS_LOCAL_STORAGE_KEY];
  const promises = storedData.map((d) => Api.project(d.id).then((res) => res.data));
  try {
    const inflatedData = mergeById(await Promise.all(promises), storedData);
    commit(types.LOAD_FREQUENT_ITEMS, { key: PROJECTS_LOCAL_STORAGE_KEY, data: inflatedData });
  } catch {
    createFlash({ message: __('There was a problem fetching recent projects.') });
  }
};

export const setFrequentGroup = ({ state, commit }, item) => {
  const frequentItems = setFrequentItemToLS(GROUPS_LOCAL_STORAGE_KEY, state.frequentItems, item);
  commit(types.LOAD_FREQUENT_ITEMS, { key: GROUPS_LOCAL_STORAGE_KEY, data: frequentItems });
};

export const setFrequentProject = ({ state, commit }, item) => {
  const frequentItems = setFrequentItemToLS(PROJECTS_LOCAL_STORAGE_KEY, state.frequentItems, item);
  commit(types.LOAD_FREQUENT_ITEMS, { key: PROJECTS_LOCAL_STORAGE_KEY, data: frequentItems });
};

export const setQuery = ({ commit }, { key, value }) => {
  commit(types.SET_QUERY, { key, value });
};

export const applyQuery = ({ state }) => {
  visitUrl(setUrlParams({ ...state.query, page: null }));
};

export const resetQuery = ({ state }) => {
  visitUrl(setUrlParams({ ...state.query, page: null, state: null, confidential: null }));
};
