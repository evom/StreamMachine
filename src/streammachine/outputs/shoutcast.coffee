_u = require 'underscore'
icecast = require("icecast-stack")

module.exports = class Shoutcast
    constructor: (stream,req,res) ->
        @req = req
        @res = res
        @stream = stream
                
        # convert this into an icecast response
        @res = new icecast.IcecastWriteStack @res, @stream.meta_interval
        @res.queueMetadata StreamTitle:@stream.source.metaTitle, StreamUrl:@stream.source.metaURL
        #console.log "sending title / url", @stream.source.metaTitle, @stream.source.metaURL
        
        headers = 
            "Content-Type":         "audio/mpeg"
            "Connection":           "close"
            "Transfer-Encoding":    "identity"
            "icy-name":             @stream.name
            "icy-metaint":          @stream.meta_interval
            
        # register ourself as a listener
        @stream.registerListener(@)
        
        # write out our headers
        res.writeHead 200, headers
        
        @metaFunc = (data) =>
            if data.StreamTitle
                @res.queueMetadata data

        @dataFunc = (chunk) => @res.write(chunk)
        
        # -- send a preroll if we have one -- #
        
        if @stream.preroll
            @stream.preroll.pump @res, => @connectSource()
        else
            @connectSource()

        # -- what do we do when the connection is done? -- #
        
        @req.connection.on "close", =>
            # stop listening to stream
            @stream.removeListener "data", @dataFunc
            
            # and to metadata
            @stream.removeListener "metadata", @metaFunc
            
            # tell the caster we're done
            @stream.closeListener(@)

    #----------
        
    connectSource: ->
        # -- now connect to our source -- #            
        
        @stream.on "metadata",   @metaFunc
        @stream.on "data",       @dataFunc
                            
