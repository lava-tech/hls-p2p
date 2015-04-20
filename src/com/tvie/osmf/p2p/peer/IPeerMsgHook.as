package com.tvie.osmf.p2p.peer 
{
    import com.tvie.osmf.p2p.events.PeerMsgEvent;
    
    /**
     * ...
     * @author dista
     */
    public interface IPeerMsgHook 
    {
        /**
         * hook and do some staff before DefaultP2PNetwork
         * @param event
         * @return
         */
        function hook(event:PeerMsgEvent):Boolean;
    }
    
}