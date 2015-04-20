package com.tvie.osmf.p2p.events 
{
    import com.tvie.osmf.p2p.P2PNetworkRepairer;
    import com.tvie.osmf.p2p.peer.Peer;
	import flash.events.Event;
	
	/**
     * ...
     * @author dista
     */
    public class P2PNetworkRepairerEvent extends Event 
    {
        public static const ON_STATUS:String = "Status";
        
        public static const REPAIR_OK:String = "P2PNetworkRepairerEvent.Repair.OK";
        public static const REPAIR_ERROR:String = "P2PNetworkRepairerEvent.Repair.Error";
        public static const REPAIR_DATA_ERROR:String = "P2PNetworkRepairerEvent.RepairData.Error";
        
        public function P2PNetworkRepairerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
        {
            super(type, bubbles, cancelable);
			
        }
        
        public var code:String;
        public var repairer:P2PNetworkRepairer;
        public var newPeers:Vector.<Peer>;
        public var failedPeers:Vector.<Peer>;
        
        public var failedDataUrl:String;
        public var failedDataReason:String;
    }

}