// use require syntax to work with migrations
const Sequelize = require('sequelize');
const configs = require('../../database.js');

const env = process.env.NODE_ENV || 'development';
const config = configs[env];

let sequelizeInst;

if (config.use_env_variable) {
  sequelizeInst = new Sequelize(process.env[config.use_env_variable]);
} else {
  sequelizeInst = new Sequelize(config.database, config.username, config.password, config);
}

module.exports = {
  sequelize: sequelizeInst,
  DataTypes: Sequelize
};
