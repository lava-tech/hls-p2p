package com.tvie.osmf.p2p.source 
{
    import com.tvie.osmf.p2p.data.ChunkCache;
    import flash.errors.IllegalOperationError;
	/**
     * round-robin selector
     * ...
     * @author dista
     */
    public class RRContentServerSelector implements IContentServerSelector 
    {
        
        public function RRContentServerSelector(contentServers:Vector.<String>, serverType:String
            ) 
        {
            if (serverType != ContentServer.HTTP_SERVER) {
                throw new ArgumentError("invalid serverType");
            }
            
            serverType_ = serverType;
            for (var i:int = 0; i < contentServers.length; i++) {
                if (serverType_ == ContentServer.HTTP_SERVER) {
                    var server:ContentServer = new HttpContentServer("http://" + contentServers[i]);
                    servers_.push(server);
                }
            }
        }
        
        /* INTERFACE com.tvie.osmf.p2p.IContentServerSelector */
        
        public function select():ContentServer 
        {
            if (servers_.length == 0) {
                throw new Error("no server can be selected");    
            }
            
            var cs:ContentServer = servers_[rrIdx_++];
            
            rrIdx_ %= servers_.length;
            
            return cs;
        }
        
        private var serverType_:String;
        private var servers_:Vector.<ContentServer> = new Vector.<ContentServer>();
        private var rrIdx_:int = 0;
    }

}