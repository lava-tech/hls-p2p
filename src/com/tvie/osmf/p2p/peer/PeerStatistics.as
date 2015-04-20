package com.tvie.osmf.p2p.peer 
{
    import flash.utils.getTimer;
	/**
     * ...
     * @author dista
     */
    public class PeerStatistics 
    {
        
        public function PeerStatistics() 
        {
            startTime_ = getTimer();
        }
        
        public function get inBytes():Number {
            return inBytes_;
        }
        
        public function set inBytes(val:Number):void {
            inBytes_ = val;
        }
        
        public function get outBytes():Number {
            return outBytes_;
        }
        
        public function set outBytes(val:Number):void {
            outBytes_ = val;
        }
        
        public function get inAvarageSpeed():Number {
            var passedTime:int = getTimer() - startTime_;
            
            if (passedTime == 0) {
                return 0;
            }
            
            return inBytes_ / passedTime;
        }
        
        public function get outAvarageSpeed():Number {
            var passedTime:int = getTimer() - startTime_;
            
            if (passedTime == 0) {
                return 0;
            }
            
            return outBytes_ / passedTime;
        }
        
        private var inBytes_:Number = 0;
        private var startTime_:int;
        private var outBytes_:Number = 0;
    }

}