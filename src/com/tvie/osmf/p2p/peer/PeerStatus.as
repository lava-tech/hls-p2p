package com.tvie.osmf.p2p.peer 
{
    import flash.utils.getTimer;
	/**
     * ...
     * @author dista
     */
    public class PeerStatus 
    {
        
        public static const PULL_MODE:String = "pullMode";
        public static const PULL_TO_PUSH:String = "pullToPush";
        public static const PUSH_TO_PULL:String = "pushToPull";
        public static const PUSH_MODE:String = "pushMode";
        public static const PUSH_MODE_PAUSED:String = "pushModePaused";
        public static const PUSH_MODE_RESUME:String = "pushModeResume";
        
        public function PeerStatus() 
        {
            
        }
        
        public function get mode():String {
            return mode_;
        }
        
        public function set mode(val:String):void {
            mode_ = val;
        }
        
        public function get canBeRemoved():Boolean {
            if (mode_ == PULL_MODE) {
                return true;
            }
            
            return false;
        }
        
        private var mode_:String = PULL_MODE;
    }

}