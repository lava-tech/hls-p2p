package com.tvie.osmf.p2p 
{
    import com.tvie.osmf.p2p.data.Chunk;
    import com.tvie.osmf.p2p.peer.IPeerMsgHook;
    import flash.errors.IllegalOperationError;
	import flash.events.EventDispatcher;
    import com.tvie.osmf.p2p.peer.Peer;
    import flash.events.IEventDispatcher;
    import flash.utils.IDataInput;
	
    [Event(name = "Status", type = "com.tvie.osmf.p2p.events.P2PNetworkEvent")]
    
	/**
     * ...
     * @author dista
     */
    public class P2PNetworkBase extends EventDispatcher
    {
        
        public function P2PNetworkBase() 
        {
            
        }
        
        public function findPeers(uri:String):void {
            
        }
        
        public function changeToP2P(uri:String):void {
            
        }
        
        public function getChunk(uri:String, dispatcher:IEventDispatcher, timeout:int):void {
            
        }
        
        public function chunkUpdated(chunk:Chunk):void {
            throw new Error("not implemented");
        }
        
        public function getBytes(numBytes:int = 0):IDataInput {
            throw new IllegalOperationError("override it");
        }
        
        public function get isOpen():Boolean {
            throw new Error("not implemented");
        }
        
        public function get isComplete():Boolean {
            throw new Error("not implemented");
        }
        
        public function get hasData():Boolean {
            throw new Error("not implemented");
        }
        
        public function get hasErrors():Boolean {
            throw new Error("not implemented");
        }
        
        public function get downloadDuration():Number {
            throw new Error("not implemented");
        }
        
        public function get downloadBytesCount():Number {
            throw new Error("not implemented");
        }
        
        public function get totalAvailableBytes():int {
            throw new Error("not implemented");
        }
        
        public function clearSavedBytes():void {
            throw new Error("not implemented");
        }
        
        public function appendToSavedBytes(source:IDataInput, count:uint):void {
            throw new Error("not implemented");
        }
        
        public function saveRemainingBytes():void {
            throw new Error("not implemented");
        }
        
        public function close(dispose:Boolean = false):void {
            throw new Error("not implemented");
        }
        
        public function canHandleMorePeer(peerID:String):Boolean {
            throw new Error("not implemented");
        }
    }

}