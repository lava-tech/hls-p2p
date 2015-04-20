package com.tvie.osmf.p2p 
{
    import com.tvie.osmf.p2p.peer.Peer;
    import com.tvie.osmf.p2p.peer.PeerStatistics;
    import flash.external.ExternalInterface;
    import flash.utils.Dictionary;
    
	/**
     * ...
     * @author dista
     */
    public class JavascriptCall 
    {
        
        public function JavascriptCall() 
        {
            
        }
        
        public static function set_app_peer_id(resourceName:String, peerID:String):void
        {
            if(ExternalInterface.available){
                ExternalInterface.call("set_app_peer_id", resourceName, peerID);
            }
        }
        
        /**
         * 
         * @param info
         * {type: source_change, data: changed_source}
         * 
         */
        public static function set_p2p_info(info:Object):void {
            if(ExternalInterface.available){
                ExternalInterface.call("set_p2p_info", info);
            }
        }
        
        /**
         * Not js function
         * @param changed_source
         */
        public static function set_source_change(changed_source:String):void {
            var info:Object = new Object();
            info["type"] = "source_change";
            info["data"] = changed_source;
            
            set_p2p_info(info);
        }
        
        public static function set_downstream_peers(downstream_peers:Vector.<String>):void {
            var info:Object = new Object();
            info["type"] = "downstream_peers";
            info["data"] = downstream_peers;
            
            set_p2p_info(info);
        }
        
        public static function set_upstream_peers(upstream_peers:Vector.<String>):void {
            var info:Object = new Object();
            info["type"] = "upstream_peers";
            info["data"] = upstream_peers;
            
            set_p2p_info(info);
        }
        
        public static function set_upstream_peer_info(obj:Object):void {
            var info:Object = new Object();
            info["type"] = "upstream_peer_info";
            info["data"] = obj;
            
            set_p2p_info(info);
        }
        
        public static function set_downstream_peer_info(obj:Object):void {
            var info:Object = new Object();
            info["type"] = "downstream_peer_info";
            info["data"] = obj;
            
            set_p2p_info(info);
        }
        
        public static function set_downstream_speed(current:String, avarage:String):void {
            var info:Object = new Object();
            info["type"] = "downstream_speed";
            info["data"] = {"current": current, "avarage": avarage};
            
            set_p2p_info(info);
        }
        
        public static function set_peers_statistics(peers:Dictionary):void {
            var info:Object = new Object();
            info["type"] = "peer_statistics";
            
            var data:Array = [];
            
            for (var k:String in peers) {
                var d:Object = new Object();
                var peer:Peer = peers[k];
                d["id"] = k;
                d["inBytes"] = peer.statistics.inBytes;
                d["inAvarageSpeed"] = peer.statistics.inAvarageSpeed;
                d["outBytes"] = peer.statistics.outBytes;
                d["outAvarageSpeed"] = peer.statistics.outAvarageSpeed;
                
                data.push(d);
            }
            
            info["data"] = data;
            
            set_p2p_info(info);
        }
    }

}