/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-2016 Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

import React, { PropTypes } from 'react';
import withStyles from 'isomorphic-style-loader/lib/withStyles';
import s from './Footer.scss';

const Footer = ({ user }) => {
  let logoutSection;

  if (user.id !== undefined) {
    logoutSection = (
      <div className={s.container}>
        <span className={s.text}>
          {user.name}
        </span>
        <span className={s.spacer} />
        <a className={s.link} href="/logout">Log Out</a>
      </div>
    );
  }

  return (
    <div className={s.root}>
      {logoutSection}
      <div className={s.container}>
        <a
          className={s.link}
          href="https://github.com/labzero/lunch"
          target="_blank"
          rel="noopener noreferrer"
        >
          GitHub
        </a>
        <span className={s.spacer} />
        <span className={s.text}>
          ©
          <a
            className={s.link}
            href="https://labzero.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            Lab Zero
          </a>
        </span>
      </div>
    </div>
  );
};

Footer.propTypes = {
  user: PropTypes.object.isRequired
};

export default withStyles(s)(Footer);
