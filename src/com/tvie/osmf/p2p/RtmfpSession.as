package com.tvie.osmf.p2p 
{
    import com.tvie.osmf.p2p.utils.RemoteLogger;
    import flash.events.NetStatusEvent;
	import flash.net.NetConnection;
    import flash.external.ExternalInterface;
	
	/**
     * ...
     * @author dista
     */
    public class RtmfpSession extends NetConnection 
    {
        
        public function RtmfpSession() 
        {
            super();
            
            addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        }
        
        public function get sessionID():String {
            if (connectedTime_ == null) {
                return "[Unknown]";
            }
            else {
                if (sessionID_ == null) {
                    sessionID_ = "" + connectedTime_.getTime()
                                 + "|" + nearID.substr(0, 7);
                }
                
                return sessionID_;
            }
        }
        
        private function setResourceName(s:String):void {
            var idx:int = 0;
            for (var i:int = (s.length - 1); i >= 0; i--) {
                if (s.charAt(i) == '/') {
                    idx = i;
                    break;
                }
            }
            
            resourceName_ = s.substring(idx + 1);
        }
        
        public function get resouceName():String {
            return resourceName_;
        }
        
        private function onNetStatus(event:NetStatusEvent):void {
            switch(event.info.code){
                case "NetConnection.Connect.Success":
                    connectedTime_ = new Date();
                    DebugLogger.log(sessionID + " RtmfpSession: connect spend " + 
                            (connectedTime_.getTime() - startTime_.getTime()) + "ms");
                    break;
            }
        }
        
        override public function connect (command:String, ...rest) : void {
            if (command.indexOf("rtmfp://") != 0) {
                throw new ArgumentError("command need start with rtmfp://");
            }
            
            resourceName_ = rest[0];
            
            startTime_ = new Date();
            
            var args:Array = new Array();
            args.push(command);
            args.push.apply(args, rest);
            super.connect.apply(this, args);
        }
        
        private var sessionID_:String = null;
        private var connectedTime_:Date = null;
        private var startTime_:Date = null;
        private var resourceName_:String = null;
    }

}