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
import hasRole from '../../../helpers/hasRole';
import loadComponent from '../../../helpers/loadComponent';
import renderIfHasName from '../../helpers/renderIfHasName';
import render404 from '../../helpers/render404';

const title = 'Tags';

export default {

  path: '/tags',

  action(context) {
    const state = context.store.getState();
    const user = state.user;
    const team = state.team;

    return renderIfHasName(context, async () => {
      if (team.id && hasRole(user, team)) {
        const TagsContainer = await loadComponent(
          () => require.ensure([], require => require('./TagsContainer').default, 'tags')
        );

        return {
          title,
          chunk: 'tags',
          component: (
            <LayoutContainer path={context.url}>
              <TagsContainer title={title} />
            </LayoutContainer>
          ),
        };
      }
      return render404;
    });
  }
};