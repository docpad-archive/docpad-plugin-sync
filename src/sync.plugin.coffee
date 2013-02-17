# Prepare
balUtil = require('bal-util')
pathUtil = require('path')
net = require('net')
Emitter = require('scuttlebutt/events')

# Export
module.exports = (BasePlugin) ->
	# Define
	class SyncPlugin extends BasePlugin
		# Name
		name: 'sync'

		# Config
		config:
			inPort:  null
			outPort: null

		# =============================
		# Events

		docpadReady: (opts) ->
			# Prepare
			config = @getConfig()
			docpad = @docpad
			database = docpad.getDatabase()

			# -------------------------
			# In

			if config.inPort
				# Log
				docpad.log 'notice', "Importing data on #{config.inPort}"

				# Setup
				syncInEmitter = new Emitter()
				syncInStream = syncInEmitter.createStream()
				serverStream = net.connect(config.inPort)
				serverStream.pipe(syncInStream).pipe(serverStream)

				# Test
				# serverStream.pipe(process.stdout)

				regenerateTimeout = null
				queueRegenerate = ->
					if regenerateTimeout
						clearTimeout(regenerateTimeout)
					regenerateTimeout = setTimeout(->
						docpad.action('generate',{reset:false})
					,1*1000)

				# Add
				syncInEmitter.on 'add', (data) ->
					#console.log 'add', data
					database.add(data)
					queueRegenerate()

				# Change
				syncInEmitter.on 'change', (data) ->
					#console.log 'change', data
					model = database.get(data.id)
					if model
						model.set(data)
					else
						database.add(data)
					queueRegenerate()

				# Remove
				syncInEmitter.on 'remove', (data) ->
					#console.log 'remove', data
					database.remove(data.id)
					queueRegenerate()

				# Reset
				syncInEmitter.on 'reset', (data) ->
					#console.log 'reset', data
					database.reset(data)
					queueRegenerate()


			# -------------------------
			# Out

			if config.outPort
				# Log
				docpad.log 'notice', "Exporting data on #{config.outPort}"

				# Setup
				syncOutEmitter = new Emitter()
				net.createServer((clientStream) ->
					docpad.log 'notice', "New connection"
					syncOutStream = syncOutEmitter.createStream()
					# it doesn't send the history here... why?
					syncOutStream
						.pipe(clientStream)
						.pipe(syncOutStream)
				).listen(config.outPort)

				# Test
				# syncOutStreamAll = syncOutEmitter.createStream()
				# syncOutStreamAll.pipe(process.stdout)

				# Add
				database.on 'add', (model, collection, opts) ->
					data = model.toJSON()
					#scuttlebuttModel.set(model.id, data)
					console.log 'add'
					syncOutEmitter.emit 'add', data

				# Change
				database.on 'change', (model, collection, opts) ->
					data = model.toJSON()
					#scuttlebuttModel.set(model.id, data)
					console.log 'change'
					syncOutEmitter.emit 'change', data

				# Remove
				database.on 'remove', (model, collection, opts) ->
					data = model.toJSON()
					#scuttlebuttModel.set(model.id, null)
					console.log 'remove'
					syncOutEmitter.emit 'remove', data

				# Reset
				database.on 'reset', (collection, opts) ->
					data = database.toJSON()
					#for model in data
					#	scuttlebuttModel.set(model.id, model.toJSON())
					console.log 'reset'
					syncOutEmitter.emit 'reset', data

