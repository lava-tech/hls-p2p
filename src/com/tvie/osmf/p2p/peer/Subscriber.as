package com.tvie.osmf.p2p.peer 
{
    import com.tvie.osmf.p2p.events.SubscribeMsgEvent;
    import com.tvie.osmf.p2p.events.SubscriberEvent;
    import com.tvie.osmf.p2p.RtmfpSession;
    import flash.errors.IOError;
    import flash.events.AsyncErrorEvent;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.StatusEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
    [Event(name = "Status", type = "com.tvie.osmf.p2p.events.SubscriberEvent")]
    [Event(name = "Message", type = "com.tvie.osmf.p2p.events.SubscribeMsgEvent")]
    
	/**
     * ...
     * @author dista
     */
    public class Subscriber extends EventDispatcher 
    {
        
        public function Subscriber(session:RtmfpSession, peerID:String, publishPointID:String) 
        {
            session_ = session;
            peerID_ = peerID;
            publishPointID_ = publishPointID;
        }
        
        public function get isSubscribed():Boolean {
            return isSubscribed_;
        }
        
        public function subscribe():void {
            stream_ = new NetStream(session_, peerID_);
            stream_.client = this;
            stream_.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
            stream_.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
            stream_.addEventListener(StatusEvent.STATUS, onStatus);
            
            stream_.play(publishPointID_);
            DebugLogger.log(session_.sessionID + " subscribe: id: " + peerID_ + " name: " + publishPointID_);
        }
        
        public function close():void {
            if (stream_) {
                stream_.close();
            }
        }
        
        public function cmdMsg(obj:Object):void {
            var e:SubscribeMsgEvent = new SubscribeMsgEvent(SubscribeMsgEvent.ON_MSG, obj);
            dispatchEvent(e);
        }
        
        public function cmdHello():void {
            DebugLogger.log(session_.sessionID + " Subscriber: cmdHello");
        }
        
        private function onIOError(event:IOErrorEvent):void {
            DebugLogger.log(session_.sessionID + " Subscriber: onIOError");
        }
        
        private function onNetStatus(event:NetStatusEvent):void {
            DebugLogger.log(session_.sessionID + " Subscriber: onNetStatus, code: " + event.info.code);
            if (event.info.code == "NetStream.Play.Start") {
                /*
                if (event.info.description.indexOf(publishPointID_) != -1)
                {
                    DebugLogger.log("play OK");
                }
                DebugLogger.log("Subscriber: peerID: " + peerID_ + " publishPointID_: " + publishPointID_ + ". info description: " + event.info.description);
                */
                
                isSubscribed_ = true;
                
                // dispatch event
                var e:SubscriberEvent = new SubscriberEvent(SubscriberEvent.ON_STATUS);
                e.code = SubscriberEvent.SUBSCRIBE_OK;
                dispatchEvent(e);
            }
            else if (event.info.code == "NetStream.Play.Failed") {
                e = new SubscriberEvent(SubscriberEvent.ON_STATUS);
                e.code = SubscriberEvent.SUBSCRIBE_ERROR;
                dispatchEvent(e);
            }
        }
        
        private function onStatus(event:StatusEvent):void {
            DebugLogger.log(session_.sessionID + " Subscriber: onStatus");
        }
        
        private var stream_:NetStream = null;
        private var session_:RtmfpSession;
        private var peerID_:String;
        private var publishPointID_:String;
        private var isSubscribed_:Boolean = false;
    }

}