package com.tvie.osmf.p2p.events 
{
	import flash.events.Event;
    import flash.utils.ByteArray;
	
	/**
     * ...
     * @author dista
     */
    public class ContentServerEvent extends Event 
    {
        public static const STATUS:String = "ContentServerStatus";
        
        public static const PROGRESS:String = "ContentServerStatus.Progress";
        public static const COMPLETE:String = "ContentServerStatus.Complete";
        public static const ERROR:String = "ContentServerStatus.Error";
        
        public function ContentServerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
        public var code:String;
        public var data:ByteArray = null;
        
        public var url:String;
        public var reason:String;
    }

}