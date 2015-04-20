package com.tvie.osmf.p2p.peer 
{
    import com.tvie.osmf.p2p.events.PublishPointEvent;
    import com.tvie.osmf.p2p.P2PNetworkBase;
    import com.tvie.osmf.p2p.RtmfpSession;
	import flash.events.EventDispatcher;
    import flash.events.NetStatusEvent;
    import flash.net.NetStream;
	
    [Event(name = "NewPeerConnected", type = "com.tvie.osmf.p2p.events.PublishPointEvent")]
    [Event(name = "PublishStart", type = "com.tvie.osmf.p2p.events.PublishPointEvent")]
    
	/**
     * ...
     * @author dista
     */
    public class PublishPoint extends EventDispatcher 
    {
        
        public function PublishPoint(session:RtmfpSession, isBroadcast:Boolean, p2pNetwork:P2PNetworkBase) 
        {
            session_ = session;
            isBroadcast_ = isBroadcast;
            p2pNetwork_ = p2pNetwork;
        }
        
        public function publish(publishID:String = null):void {
            publishID_ = publishID;
            stream_ = new NetStream(session_, NetStream.DIRECT_CONNECTIONS);
            stream_.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
            stream_.client = new Object();
            stream_.client.onPeerConnect = onPeerConnect;
            
            if (publishID === null) {
                DebugLogger.log(session_.sessionID + " PublishPoint: id: " + session_.nearID + " name: " + session_.nearID);
                publishID_ = session_.nearID;
                stream_.publish(session_.nearID);
            }
            else {
                DebugLogger.log(session_.sessionID + " PublishPoint: id: " + session_.nearID + " name: " + publishID);
                stream_.publish(publishID);
            }
        }
        
        public function get hasSubscriber():Boolean {
            return hasSubscriber_;
        }
        
        public function broadcast(handlerName:String, ...rest):void {
            var args:Array = new Array();
            args.push(handlerName);
            args.push.apply(args, rest);
            stream_.send.apply(stream_, args);
        }
        
        public function close():void {
            // TODO: See if it works
            if (stream_) {
                stream_.close();
            }
        }
        
        private function onPeerConnect(peer:NetStream):Boolean {
            if (!isBroadcast_ && hasSubscriber_) {
                // in case. this should never happen
                DebugLogger.log(session_.sessionID + " two more user connect to private publishpoint happend");
                return false;
            }
            
            hasSubscriber_ = true;
            return p2pNetwork_.canHandleMorePeer(peer.farID);
                        
            //var event:PublishPointEvent = new PublishPointEvent(PublishPointEvent.NEW_PEER_CONNECTED);
            //event.peerID = peer.farID;
            //dispatchEvent(event);
        }
        
        private function onNetStatus(event:NetStatusEvent):void {
            DebugLogger.log(session_.sessionID + " PublishPoint: onNetStatus. code: " + event.info.code);
            switch(event.info.code) {
                case "NetStream.Publish.Start":                    
                    if (published_)
                        throw new Error("bug, already published");
                    published_ = true;
                    var e:PublishPointEvent = new PublishPointEvent(PublishPointEvent.PUBLISH_START);
                    dispatchEvent(e);
                    break;
                case "NetStream.Play.Start":
                    var pe:PublishPointEvent = new PublishPointEvent(PublishPointEvent.NEW_PEER_CONNECTED);
                    var ns:NetStream = event.target as NetStream;
                    pe.peerID = ns.peerStreams[ns.peerStreams.length - 1].farID;
                    dispatchEvent(pe);
                    break;
                default:
                    break;
            }
        }
        
        private var session_:RtmfpSession;
        private var stream_:NetStream = null;
        private var published_:Boolean = false;
        private var hasSubscriber_:Boolean = false;
        private var isBroadcast_:Boolean;
        
        private var publishID_:String;
        private var p2pNetwork_:P2PNetworkBase;
    }

}