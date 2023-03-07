#include <amxmodx>
#include <cstrike>
#include <hlsdk_const>
#include <fakemeta>
#include <engine>
#include <esf>

/*
    功能函数:
    1:解决spec_mode 卡观察者杀人bug
    2:可选择死亡次数后复活成为观察者
    3:提供音效反馈,全局respwan玩家复活限制,踢出bot函数..
    整理:单挑函数需要的部分,限制杀人,死亡次数√，成为观察者√,观察者重置分数，自动开启菜单

*/

#define MAXDEATH_EAZY 3
#define MAXFARGS_EAZY 3

new GoodIndex=0,
    EvilIndex=0,
    g_WarriorLimt[33],
    bool:g_iBattle,
    bool:g_iWarrior[33];


public plugin_precache()
{
   	precache_sound("battleplug/0.wav");
	precache_sound("battleplug/1.wav");
	precache_sound("battleplug/2.wav");
	precache_sound("battleplug/3.wav");
	precache_sound("battleplug/start.wav");
	precache_sound("battleplug/error.wav");
	precache_sound("battleplug/hp.wav");
}

public client_disconnected(id)
{
    if(g_iWarrior[id]==true)
    {
        g_iWarrior[id]=false;
    }

    g_WarriorLimt[id]=0;
}

public blockSmk(id)
{
    static sz_agv[20];
    read_argv(0,sz_agv,sizeof(sz_agv))

    if(equal(sz_agv,"teleport"))
    {
        ResetScreenFade(0,0,0,1,2,3,0);
        return FMRES_SUPERCEDE
    }

    return FMRES_IGNORED;
}

public hookcmd(id)
{
    // 获取服务器的dbase_name
    // static sz[20],parm[11];

    // read_argv(0,sz,sizeof(sz));
    // read_argv(0,parm,sizeof(parm));

    // client_print(id,print_chat,"第一个参数:%s",sz);
    // client_print(id,print_chat,"第二个参数:%s",parm);

    client_print(id,print_chat,"禁止使用该命令");
    
    PlaySound(id,"battleplug/error.wav");

    return FMRES_IGNORED;
}

public TeamChange(Index)
{
    new 
    goodC=0,
    evilC=0;

    for(new i=1;i<get_maxplayers();i++)
    {
        if(!is_user_alive(i)&&!is_user_connected(i))continue;

        if(Get_Team(i)==1)
        {
            goodC++;
            if(goodC>=2)
            {
                client_cmd(i,"jointeam 2");
                client_print(i,print_chat,"善恶");
            }
        }
        else if(Get_Team(i)==2)
        {
            evilC++;
            if(evilC>=2)
            {
                client_cmd(i,"jointeam 1");
                client_print(i,print_chat,"恶善");
            }
        }
    }
}

public PlayerPreThink(id)
{
    new playerCount = 0;

    for(new i = 1 ; i < get_maxplayers() ; i++)
    {
        if(!is_user_alive(id) && !is_user_connected(id))continue;

        if(Get_Team(i)>0)
        {
            playerCount++;
        }

        if(playerCount > 1)break;
    }

    UpData();

    if(playerCount<=1)
    {
        g_iBattle=false;
        resetAll();
    }
    else if(playerCount>1)
    {
        g_iBattle=true;
    }

    return FMRES_IGNORED;
}

public event_deathmsg()
{   
    new attack=read_data(1);
    new victim=read_data(2);

    new death=get_user_deaths(victim);
    
    // g_iWarrior[victim]=false;

    if(g_iWarrior[victim] && g_iBattle)return;

    client_print(victim,print_chat,"g_iWarrior=%d",g_iWarrior[victim]);

    ++death;

    if(!attack || attack==victim)
    {
        ++death;
    }

    //debug
    client_print(victim,print_chat,"%d次死亡",death);

    if(death>=MAXDEATH_EAZY)
    {
        g_iWarrior[victim]=true;
        forceSpectator(victim);
        PlayLoser(victim);
        client_cmd(victim, "+jump;wait");
        set_task(0.6,"MyFunctionSpawn",victim,_,_,"a",2);
    }

    checkWinner();  
}

public MyFunctionSpawn(id)
{
    client_cmd(id, "+jump;wait;-jump");
}

public SetSpawn(id)
{
    // Disconnected, already spawned, or switched to Spectator
    if (!is_user_connected(id) || is_user_alive(id) || get_user_team(id)==3)
        return;
    
    // (Debug only)
    // client_print(0, print_chat, "Player %d is being respawned", id)
    
    // 给予玩家死亡等待复活状态并且思考
    set_pev(id, pev_deadflag, DEAD_RESPAWNABLE)
    dllfunc(DLLFunc_Think, id)
    
    //检测玩家是否给予等待复活的状态.
    if (pev(id, pev_deadflag) == DEAD_RESPAWNABLE)
    {
        dllfunc(DLLFunc_Spawn, id);
    }
}

public playerSpawn(id)
{
    if(!g_iBattle)return;

    if(!g_iWarrior[id])return;

    if(!is_user_alive(id))return;

    if(Is_Bot(id))
    {
        KickBot(id);
    }

    client_print(id,print_chat,"啊啊aa开始比赛了吗~3ge头,禁止~嗯！啊~哦。");

    client_cmd(id,"spectate");

    forceSpectator(id);
    
    PlaySound(id, "battleplug/error.wav");
}

public forceSpectator(id)
{
    if(!is_user_connected(id))return;

    new team = entity_get_int(id,EV_INT_team);

    if(Is_Bot(id))
    {
        KickBot(id);
    }

    if(team>0)
    {
        
        client_cmd(id,"spectate");

        set_task(1.0,"forceSpectator",id);
    }

    ResetScored(id,0,0);
}

public ResetScored(id,frags,deaths)
{

    set_pev(id,pev_frags,frags);
    set_pdata_int(id,604,deaths);

    message_begin(MSG_ALL,75);
    write_byte(id);
    write_short(frags);
    write_short(deaths);
    write_short(0);
    write_short(0);
    write_short(Get_Team(id));
    message_end();
}

public ResetS(id)
{
    set_pev(id,pev_frags,0);
    set_pdata_int(id,604,0);

    message_begin(MSG_ALL,75);
    write_byte(id);
    write_short(0);
    write_short(0);
    write_short(0);
    write_short(0);
    write_short(Get_Team(id));
    message_end();
}

public ResetScreenFade(Duration,HoldTime,Flags,ColorR,ColorG,ColorB,Alpha)
{
	message_begin(MSG_ALL,get_user_msgid("ScreenFade"));
	write_short(0);
	write_short(0);
	write_short(0x0000);
	write_byte(1);
	write_byte(2);
	write_byte(3);
	write_byte(0);
	message_end();

	return	PLUGIN_CONTINUE;
}

public set_kill(id)
{
    user_silentkill(id);
}

public KickBot(id)
{
    if(!is_user_connected(id))return;

    server_cmd("kick #%d",get_user_userid(id));
}

public resetall(id)
{
    g_iBattle=false;
    
    for(new j=1;j<get_maxplayers();j++)
    {
        g_iWarrior[j]=false;
    }

    client_print(id,print_chat,"重置");
}

public seekstatus(id)
{
    //debug
    client_print(id,print_chat,"g_ibattle的状态:%d",g_iBattle);
    client_print(id,print_chat,"g_iWarrior的状态:%d",g_iWarrior[id]);
    client_print(id,print_chat,"g_goodIndex的索引号:%d",GoodIndex);
    client_print(id,print_chat,"g_EvilIndex的索引号:%d",EvilIndex);
}

public seekData(id)
{
    new classType;
    classType=get_pdata_int(id,1972);

    client_print(id,print_chat,"classname:%d",classType);
}

stock Get_Team(Index)
{
    new szTeamName[2];
    
    get_user_team(Index,szTeamName,1);

    switch(szTeamName[0])
    {
        case 'G':return 1;//good
        case 'E':return 2;//evil
    }

    return 0;
}

stock Is_Bot(Index)
{
    return (entity_get_int(Index,EV_INT_flags)  &  FL_FAKECLIENT ) ?   true  :  false;
}

stock PlayLoser(Index)
{
    new iMusic = random_num(1,4),szMusic[68];
    format(szMusic,67,"battleplug/lose%d.mp3",iMusic);
    PlayMusic(Index,szMusic);
}

stock MessageCenter( id, Color[ 3 ], const Message[], Float:Duration = 2.0 )
{
	set_hudmessage( Color[ 0 ], Color[ 1 ], Color[ 2 ], -1.0, 0.35, 0, 0.0, Duration, 0.0, 1.0, -1 );
	show_hudmessage( id, Message );
}

stock PlayMusic(id, const sound[] )
{
    client_cmd( id, "mp3 play ^"sound/%s^"", sound);
}

stock PlaySound(id,const sound[])
{
    client_cmd(id,"spk ^"sound/%s^"",sound);
}

stock checkWinner()
{
    new iWinner;
    new playerCount = 0;

    for( new i = 1; i < get_maxplayers(); i++ )
	{
		if( !is_user_connected( i ) )
			continue;

		if( g_iWarrior[ i ] == false )
		{
			playerCount++
			iWinner = i;
		}
			
		if( playerCount > 1 )
			break;
	}
    
    if( playerCount == 1)
	{
		new szName[ 50 ]
		get_user_name( iWinner, szName, 49 );

		PlayMusic( iWinner, "battleplug/win_music.mp3" );

		new szmsg[ 150 ];
		format( szmsg, 149, "[ WINNER : %s ]", szName );
        
		MessageCenter( 0, { 0,255,0 }, szmsg, 10.0 );
	}
}

UpData()
{
    new GoodPlayerCount=0,
        EvilPlayerCount=0;

    for(new k = 1 ; k < get_maxplayers() ; k++)
    {
        if(!is_user_alive(k) && !is_user_connected(k))continue;

        if(Get_Team(k)==1)
        {
            GoodPlayerCount++
            GoodIndex=k;
        }
        else if(Get_Team(k)==2)
        {
            EvilPlayerCount++
            EvilIndex=k;
        }
    }

    if(get_user_deaths(GoodIndex)>= MAXDEATH_EAZY|| get_user_deaths(EvilIndex)>= MAXDEATH_EAZY)return;

    if(GoodPlayerCount==1 && EvilPlayerCount==1)
    {
        g_iWarrior[GoodIndex]=false;
        g_iWarrior[EvilIndex]=false;
    }

    for (new h = 1; h < get_maxplayers(); h++)
    {
        if (h != GoodIndex && h != EvilIndex)
        {
            g_iWarrior[h] = true;
        }
    }
}

resetAll()
{
    GoodIndex=0;
    EvilIndex=0;

    for(new i=1;i<get_maxplayers();i++)
    {
        g_iWarrior[i]=false;
    }
}


public plugin_init()
{
    register_plugin("EVM_BATTLE", "0.1", "CLOUD");

    register_event("DeathMsg", "event_deathmsg", "a");
    register_event("ResetHUD","playerSpawn","b");

    register_forward(FM_ClientCommand,"blockSmk"); //获取console参数名字
    register_forward(FM_PlayerPreThink,"PlayerPreThink");

    //debug
    register_clcmd("say kill","set_kill");
    register_clcmd("say reset","resetall");
    register_clcmd("say stats","seekstatus");
    register_clcmd("say data","seekData");
    register_clcmd("say scoard","ResetS")

    register_concmd("spec_mode","hookcmd",-1);

}
