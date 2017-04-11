import React from 'react';
import withStyles from 'isomorphic-style-loader/lib/withStyles';
import Grid from 'react-bootstrap/lib/Grid';
import s from './ComingSoon.scss';

const ComingSoon = () => (
  <div className={s.root}>
    <Grid>
      <h2>Coming soon</h2>
      <p>Sign-ups are currently closed. Please check back shortly!</p>
    </Grid>
  </div>
);

export default withStyles(s)(ComingSoon);