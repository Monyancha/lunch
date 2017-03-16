/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-present Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

/* eslint-disable max-len */

export const port = process.env.PORT || 3000;
export const host = process.env.WEBSITE_HOSTNAME ||
                    process.env.DOCKERCLOUD_SERVICE_FQDN ? `${process.env.DOCKERCLOUD_SERVICE_FQDN}:${port}` : undefined ||
                    `localhost:${port}`;

export const wsHost = process.env.WS_HOST;

export const httpsPort = process.env.HTTPS_PORT || 443;
export const selfSigned = process.env.HTTPS_PRIVATEKEY === undefined ||
                          process.env.HTTPS_CERTIFICATE === undefined;
export const privateKeyPath = process.env.HTTPS_PRIVATEKEY || 'cert/server.key';
export const certificatePath = process.env.HTTPS_CERTIFICATE || 'cert/server.crt';

export const analytics = {

  // https://analytics.google.com/
  google: { trackingId: process.env.GOOGLE_TRACKING_ID || 'UA-XXXXX-X' },

};

export const auth = {

  jwt: { secret: process.env.JWT_SECRET || 'React Starter Kit' },

};
