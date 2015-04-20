package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;
	
	/**
     * ...
     * @author dista
     */
    public class P2PLoaderStatusEvent extends Event 
    {
        public static const ON_STATUS:String = "Status";
        
        // codes
        public static const CONNECTION_CLOSE:String = "P2PLoaderStatusEvent.Connection.Close";
        public static const CONNECTION_FAILED:String = "P2PLoaderStatusEvent.Connection.Failed";
        public static const CONNECTION_TIMEOUT:String = "P2PLoaderStatusEvent.Connection.Timeout";
        public static const IDX_GOT:String = "P2PLoaderStatusEvent.IDX.Got";
        
        public function P2PLoaderStatusEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false,
                                                code:String = null) 
        {
            super(type, bubbles, cancelable);
			
            this.code = code;
        }
        
        public var code:String;
        public var idxData:ByteArray;
        public var request:URLRequest;
    }

}