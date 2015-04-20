package com.tvie.osmf.p2p.source 
{
    
    /**
     * Select one ContentServer
     * @author dista
     */
    public interface IContentServerSelector 
    {
        function select():ContentServer;
    }
    
}