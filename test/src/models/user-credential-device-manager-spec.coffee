UserCredentialDeviceManager = require '../../../src/models/user-credential-device-manager'
describe 'UserCredentialDeviceManager', ->
  beforeEach ->
    @meshbluHttp =
      devices: sinon.stub()
      register: sinon.stub()
    @MeshbluHttp = sinon.spy => @meshbluHttp
    @meshbluJSON = type: 'auth-user:little-bits-cloud-proxy', logo: 'http://google.com', messageSchemaUrl: 'something'
    @dependencies =
      MeshbluHttp: @MeshbluHttp

  describe '-> create', ->
    describe 'when it works', ->
      beforeEach ->
        @meshbluHttp.register.yields null
        @sut = new UserCredentialDeviceManager @meshbluJSON, @dependencies
        @sut.create parentUuid: 'bi235', owner: '1235', proxyUuid: 'p1555', (@error) =>

      it 'should call meshbluHttp.register', ->
        expect(@meshbluHttp.register).to.have.been.calledWith
          type: 'auth-user:little-bits-cloud-proxy'
          owner: '1235'
          name: 'Little Bits'
          logo: 'http://google.com'
          messageSchemaUrl: 'something'
          configureWhitelist: ['1235']
          discoverWhitelist: ['p1555', '1235']
          parentDevice: 'bi235'
          meshblu:
            messageForward: ['bi235']

  describe '-> findOrCreate', ->
    describe 'when the service returns an unknown error', ->
      beforeEach ->
        @meshbluHttp.devices.yields new Error('something happened'), null
        @sut = new UserCredentialDeviceManager @meshbluJSON, @dependencies
        sinon.spy @sut, 'create'
        @sut.findOrCreate 'bi235', '2352', 'p1234', (@error) =>

      it 'should call meshbluHttp.devices', ->
        expect(@meshbluHttp.devices).to.have.been.calledWith type: 'auth-user:little-bits-cloud-proxy', parentDevice: 'bi235', owner: '2352'

      it 'should not call create', ->
        expect(@sut.create).not.to.have.been.called

      it 'should callback with an error', ->
        expect(@error).to.exist

    describe 'when the device does not exist', ->
      beforeEach ->
        @meshbluHttp.devices.yields new Error('Devices not found'), null
        @sut = new UserCredentialDeviceManager @meshbluJSON, @dependencies
        @newDevice = uuid: 'something'
        @sut.create = sinon.spy (params, callback) => callback null, @newDevice
        @sut.findOrCreate 'bi235', '1544', 'p235', (@error, @device) =>

      it 'should call meshbluHttp.devices', ->
        expect(@meshbluHttp.devices).to.have.been.calledWith type: 'auth-user:little-bits-cloud-proxy', parentDevice: 'bi235', owner: '1544'

      it 'should call create', ->
        expect(@sut.create).to.have.been.calledWith parentUuid: 'bi235', owner: '1544', proxyUuid: 'p235'

      it 'should callback without an error', ->
        expect(@error).not.to.exist

      it 'should callback with the new device', ->
        expect(@device).to.deep.equal @newDevice

    describe 'when the device does exist', ->
      beforeEach ->
        @oldDevice = uuid: 'oldie'
        @meshbluHttp.devices.yields null, {devices: [@oldDevice]}
        @sut = new UserCredentialDeviceManager @meshbluJSON, @dependencies
        @sut.create = sinon.spy()
        @sut.findOrCreate 'obiwef', '1245', 'p124', (@error, @device) =>

      it 'should call meshbluHttp.devices', ->
        expect(@meshbluHttp.devices).to.have.been.calledWith type: 'auth-user:little-bits-cloud-proxy', parentDevice: 'obiwef', owner: '1245'

      it 'should not call create', ->
        expect(@sut.create).not.to.have.been.called

      it 'should callback without an error', ->
        expect(@error).not.to.exist

      it 'should callback with the old device', ->
        expect(@device).to.deep.equal @oldDevice
