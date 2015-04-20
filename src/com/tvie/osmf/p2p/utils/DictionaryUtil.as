package com.tvie.osmf.p2p.utils 
{
    import flash.utils.Dictionary;
	/**
     * ...
     * @author dista
     */
    public class DictionaryUtil 
    {
        
        public function DictionaryUtil() 
        {
            
        }
        
        public static function len(d:Dictionary):int {
            var ret:int = 0;
            for (var k:* in d) {
                ret++;
            }
            
            return ret;
        }
        
    }

}