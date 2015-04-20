package  
{
    import flash.external.ExternalInterface;
    
	/**
     * ...
     * @author dista
     */
    public class DebugLogger 
    {
        
        public function DebugLogger() 
        {
            
        }
        
        public static function log2(msg:Object):void {
            CONFIG::P2P_DEBUG
            {
                var time:Number = (new Date()).getTime();
                if (ExternalInterface.available)
                {
                    ExternalInterface.call("log", "" + time + "|" + msg.toString());
                }
                else {
                    trace("" + time + "|" + msg.toString());
                }
            }
        }
        
        public static function log(msg:Object):void {
            CONFIG::P2P_DEBUG
            {
                var time:Number = (new Date()).getTime();
                if (ExternalInterface.available)
                {
                    ExternalInterface.call("log", "" + time + "|" + msg.toString());
                }
                else {
                    trace("" + time + "|" + msg.toString());
                }
            }
        }
    }

}