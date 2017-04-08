/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-present Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

import React from 'react';
import LayoutContainer from '../../../components/Layout/LayoutContainer';
import loadComponent from '../../../helpers/loadComponent';
import renderIfLoggedOut from '../../helpers/renderIfLoggedOut';

export default {

  path: '/',

  async action(context) {
    const state = context.store.getState();

    return renderIfLoggedOut(state, async () => {
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
    });
  },
};
