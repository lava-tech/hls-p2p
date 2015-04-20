package com.tvie.osmf.p2p.tracker 
{
	/**
     * ...
     * @author dista
     */
    public class TrackerFactory 
    {
        public static var instance:TrackerFactory = new TrackerFactory();
        
        public static const RTMFP_TRACKER:String = "rtmfp";
        public static const HTTP_TRACKER:String = "http"
        
        public function TrackerFactory() 
        {
            
        }
        
        public function createTracker(type:String, ...rest):TrackerBase {
            if (type == RTMFP_TRACKER) {
                return new RtmfpTracker(rest[0]);
            }
            else if (type == HTTP_TRACKER) {
                return new HttpTracker(rest[0]);
            }
            
            throw new ArgumentError("invalid type");
        }
    }

}