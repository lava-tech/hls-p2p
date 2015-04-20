package com.tvie.osmf.p2p.tracker 
{
    import com.tvie.osmf.p2p.events.TrackerEvent;
    import com.tvie.osmf.p2p.RtmfpSession;
    import flash.net.Responder;
    
	/**
     * ...
     * @author dista
     */
    public class RtmfpTracker extends TrackerBase 
    {
        private static const GET_PEERS:String = "getParticipants";
        
        public function RtmfpTracker(session:RtmfpSession) 
        {
            super();
			
            session_ = session;
        }
        
        override public function getPeers(resourceID:String, size:int):void
        {
            session_.call(GET_PEERS, new Responder(onGetPeers), resourceID);
        }
        
        private function onGetPeers(obj:Object):void {
            var event:TrackerEvent = new TrackerEvent(TrackerEvent.PEER_LIST);
            event.peers = new Vector.<String>();
            
            for (var i:int; i < obj.length; i++) {
                event.peers.push(obj[i].farID);
            }
            
            dispatchEvent(event);
        }
        
        private var session_:RtmfpSession;
    }

}