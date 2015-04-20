package com.tvie.osmf.p2p.source 
{
	/**
     * ...
     * @author dista
     */
    public class SelectorFactory 
    {
        public static const RR_SELECTOR:String = "RRSelector";
        public function SelectorFactory() 
        {
            
        }
        
        public function createSelector(type:String, ...rest):IContentServerSelector {
            if (type == RR_SELECTOR) {
                return new RRContentServerSelector(rest[0], rest[1]);
            }
            
            throw ArgumentError("invalid type: " + type);
        }
        
    }

}