const { expect } = require('chai');
const   config   = require('../config.js');

describe('Configuration Import', () => {
	const addy = '0x46ceE66cC9dC0bC113eD3319374421A70d815C9f';

	it('Should import my bot wallet', () => {
		expect(config.wallet.address).to.equal(addy);
	});
});
