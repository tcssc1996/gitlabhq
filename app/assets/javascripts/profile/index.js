import Vue from 'vue';
import VueApollo from 'vue-apollo';

import createDefaultClient from '~/lib/graphql';

import ProfileTabs from './components/profile_tabs.vue';
import UserAchievements from './components/user_achievements.vue';

Vue.use(VueApollo);

export const initProfileTabs = () => {
  const el = document.getElementById('js-profile-tabs');

  if (!el) return false;

  const {
    followees,
    followers,
    userCalendarPath,
    utcOffset,
    userId,
    snippetsEmptyState,
  } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'ProfileRoot',
    provide: {
      followees: parseInt(followers, 10),
      followers: parseInt(followees, 10),
      userCalendarPath,
      utcOffset,
      userId,
      snippetsEmptyState,
    },
    render(createElement) {
      return createElement(ProfileTabs);
    },
  });
};

export const initUserAchievements = () => {
  const el = document.getElementById('js-user-achievements');

  if (!el) return false;

  const { rootUrl, userId } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return new Vue({
    el,
    apolloProvider,
    name: 'UserAchievements',
    provide: { rootUrl, userId: parseInt(userId, 10) },
    render(createElement) {
      return createElement(UserAchievements);
    },
  });
};
