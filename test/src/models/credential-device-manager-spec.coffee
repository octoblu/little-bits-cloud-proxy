CredentialDeviceManager = require '../../../src/models/credential-device-manager'
describe 'CredentialDeviceManager', ->
  beforeEach ->
    @meshbluHttp =
      devices: sinon.stub()
      register: sinon.stub()
      updateDangerously: sinon.stub()
      update: sinon.stub()

    @MeshbluHttp = sinon.spy => @meshbluHttp
    @meshbluJSON = type: 'auth:little-bits-cloud-proxy', logo: 'http://seomthing', messageSchemaUrl: 'url', name: 'name'
    @dependencies =
      MeshbluHttp: @MeshbluHttp

  describe '-> addUserDevice', ->
    describe 'when it works', ->
      beforeEach ->
        @meshbluHttp.updateDangerously.yields null
        @sut = new CredentialDeviceManager @meshbluJSON, @dependencies
        @sut.addUserDevice 'me', 'userdev'

      it 'should call meshbluHttp.updateDangerously', ->
        expect(@meshbluHttp.updateDangerously).to.have.been.calledWith 'me', $addToSet: {sendWhitelist: 'userdev'}

  describe '-> create', ->
    describe 'when it works', ->
      beforeEach ->
        @meshbluHttp.register.yields null
        @sut = new CredentialDeviceManager @meshbluJSON, @dependencies
        @sut.create clientID: 'bi235', owner: '1235', (@error) =>

      it 'should call meshbluHttp.register', ->
        expect(@meshbluHttp.register).to.have.been.calledWith
          type: 'auth:little-bits-cloud-proxy'
          owner: '1235'
          name: 'name'
          configureWhitelist: ['1235']
          discoverWhitelist: ['1235']
          clientID: 'bi235'
          logo: 'http://seomthing'
          messageSchemaUrl: 'url'
          meshblu:
            messageForward: ['1235']

  describe '-> findOrCreate', ->
    describe 'when the service returns an unknown error', ->
      beforeEach ->
        @meshbluHttp.devices.yields new Error('something happened'), null
        @sut = new CredentialDeviceManager @meshbluJSON, @dependencies
        sinon.spy @sut, 'create'
        @sut.findOrCreate 'bi235', '2352', (@error) =>

      it 'should call meshbluHttp.devices', ->
        expect(@meshbluHttp.devices).to.have.been.calledWith type: 'auth:little-bits-cloud-proxy', clientID: 'bi235'

      it 'should not call create', ->
        expect(@sut.create).not.to.have.been.called

      it 'should callback with an error', ->
        expect(@error).to.exist

    describe 'when the device does not exist', ->
      beforeEach ->
        @meshbluHttp.devices.yields new Error('Devices not found'), null
        @sut = new CredentialDeviceManager @meshbluJSON, @dependencies
        @newDevice = uuid: 'something'
        @sut.create = sinon.spy (params, callback) => callback null, @newDevice
        @sut.findOrCreate 'bi235', '1544', (@error, @device) =>

      it 'should call meshbluHttp.devices', ->
        expect(@meshbluHttp.devices).to.have.been.calledWith type: 'auth:little-bits-cloud-proxy', clientID: 'bi235'

      it 'should call create', ->
        expect(@sut.create).to.have.been.calledWith clientID: 'bi235', owner: '1544'

      it 'should callback without an error', ->
        expect(@error).not.to.exist

      it 'should callback with the new device', ->
        expect(@device).to.deep.equal @newDevice

    describe 'when the device does exist', ->
      beforeEach ->
        @oldDevice = uuid: 'oldie'
        @meshbluHttp.devices.yields null, {devices: [@oldDevice]}
        @sut = new CredentialDeviceManager @meshbluJSON, @dependencies
        @sut.create = sinon.spy()
        @sut.findOrCreate 'obiwef', '1245', (@error, @device) =>

      it 'should call meshbluHttp.devices', ->
        expect(@meshbluHttp.devices).to.have.been.calledWith type: 'auth:little-bits-cloud-proxy', clientID: 'obiwef'

      it 'should not call create', ->
        expect(@sut.create).not.to.have.been.called

      it 'should callback without an error', ->
        expect(@error).not.to.exist

      it 'should callback with the old device', ->
        expect(@device).to.deep.equal @oldDevice

  describe '-> updateClientSecret', ->
    describe 'when it works', ->
      beforeEach ->
        @meshbluHttp.updateDangerously.yields null
        @sut = new CredentialDeviceManager @meshbluJSON, @dependencies
        @sut.updateClientSecret 'me', 'shhhhhh'

      it 'should call meshbluHttp.update', ->
        expect(@meshbluHttp.update).to.have.been.calledWith 'me', clientSecret: 'shhhhhh'
