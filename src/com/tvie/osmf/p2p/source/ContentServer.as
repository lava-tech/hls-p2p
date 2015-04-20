package com.tvie.osmf.p2p.source 
{
    import flash.errors.IllegalOperationError;
    import flash.events.IEventDispatcher;
    import flash.utils.IDataInput;
    import com.tvie.osmf.p2p.Loader;
    
	/**
     * ContentServer is used to get piece from a content server(such as http server)
     * @author dista
     */
    public class ContentServer extends Loader
    {
        public static const HTTP_SERVER:String = "http";
        
        public function ContentServer(urlBase:String) 
        {
            urlBase_ = urlBase;
        }
        
        
        
        protected var urlBase_:String;
    }

}