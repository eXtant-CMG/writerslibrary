/* global cy */
describe('The landing page', function () {
  it('should load ', function () {
    cy.visit('/exist/apps/writerslibrary/index.html')
      .get('.alert')
      .contains('app.xqm')
  })

})
