/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-present Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

import React from 'react';
import loadComponent from '../../../helpers/loadComponent';
import { getTeams } from '../../../selectors/teams';
import LayoutContainer from '../../../components/Layout/LayoutContainer';

export default {

  path: '/',

  async action(context) {
    const state = context.store.getState();
    const user = state.user;
    const host = state.host;

    if (user.id) {
      if (user.roles.length === 1) {
        const team = getTeams(state)[0];
        return {
          redirect: `//${team.slug}.${host}`
        };
      }
      return {
        redirect: '/teams'
      };
    }

    const Landing = await loadComponent(
      () => require.ensure([], require => require('./Landing').default, 'landing')
    );

    return {
      chunk: 'landing',
      component: (
        <LayoutContainer path={context.url}>
          <Landing />
        </LayoutContainer>
      ),
    };
  },
};
