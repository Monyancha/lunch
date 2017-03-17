exports.up = (queryInterface, Sequelize) =>
  queryInterface.addColumn('teams', 'slug', {
    type: Sequelize.STRING,
    unique: true,
  });

exports.down = queryInterface =>
  queryInterface.removeColumn('teams', 'slug');
