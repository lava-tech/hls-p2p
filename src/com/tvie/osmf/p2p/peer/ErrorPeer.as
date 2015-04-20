package com.tvie.osmf.p2p.peer 
{
	/**
     * ...
     * @author dista
     */
    public class ErrorPeer 
    {
        
        public function ErrorPeer(peerID:String) 
        {
            this.peerID_ = peerID;
        }
        
        public function get peerID():String {
            return peerID_;
        }
        
        public function get reason():String {
            return reason_;
        }
        
        public function set reason(val:String):void {
            reason_ = val;
        }
        
        private var peerID_:String;
        private var reason_:String;
    }

}