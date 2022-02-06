#include <sdktools>
#include <sourcemod>

public const Plugin myinfo = {
    name = "Disable Round Timer", author = "LAN of DOOM",
    description = "Disables the round timer", version = "1.0.0",
    url =
        "https://github.com/lanofdoom/counterstrikesource-disable-round-timer"};

static const char kRoundTimePropertyName[] = "m_iRoundTime";
static const char kPlantedC4EntityName[] = "planted_c4";
static const int kInfiniteRoundTime = 2147483647;

static int g_planted_c4_entity = INVALID_ENT_REFERENCE;
static int g_round_time_left_when_disabled_ms;
static int g_time_when_disabled_ms;

static ConVar g_disable_round_timer_cvar;

//
// Logic
//

static void DisableRoundTimer() {
  if (g_planted_c4_entity != INVALID_ENT_REFERENCE) {
    return;
  }

  g_round_time_left_when_disabled_ms =
      1000 * GameRules_GetProp(kRoundTimePropertyName);
  g_time_when_disabled_ms = GetSysTickCount();

  GameRules_SetProp(kRoundTimePropertyName, kInfiniteRoundTime);

  g_planted_c4_entity = CreateEntityByName(kPlantedC4EntityName);
  DispatchSpawn(g_planted_c4_entity);
}

static void EnableRoundTimer() {
  if (g_planted_c4_entity == INVALID_ENT_REFERENCE) {
    return;
  }

  int current_time_ms = GetSysTickCount();
  int elapsed_time_ms = current_time_ms - g_time_when_disabled_ms;
  int new_round_time_ms = g_round_time_left_when_disabled_ms - elapsed_time_ms;
  int new_round_time = new_round_time_ms / 1000;

  GameRules_SetProp(kRoundTimePropertyName, new_round_time);

  AcceptEntityInput(g_planted_c4_entity, "Kill");
  g_planted_c4_entity = INVALID_ENT_REFERENCE;
}

//
// Hooks
//

static Action OnRoundStart(Event event, const char[] name,
                           bool dont_broadcast) {
  g_planted_c4_entity = INVALID_ENT_REFERENCE;
  return Plugin_Continue;
}

static Action OnRoundFreezeEnd(Event event, const char[] name,
                               bool dont_broadcast) {
  if (!GetConVarBool(g_disable_round_timer_cvar)) {
    return Plugin_Continue;
  }

  DisableRoundTimer();

  return Plugin_Continue;
}

static void OnCvarChange(Handle convar, const char[] old_value,
                         const char[] new_value) {
  if (GetConVarBool(g_disable_round_timer_cvar)) {
    DisableRoundTimer();
  } else {
    EnableRoundTimer();
  }
}

//
// Forwards
//

public void OnMapEnd() {
  g_planted_c4_entity = INVALID_ENT_REFERENCE;
}

public void OnPluginStart() {
  g_disable_round_timer_cvar =
      CreateConVar("sm_lanofdoom_round_timer_disabled", "1",
                   "If true, the round timer is disabled.");

  HookConVarChange(g_disable_round_timer_cvar, OnCvarChange);
  HookEvent("round_freeze_end", OnRoundFreezeEnd);
  HookEvent("round_start", OnRoundStart);

  if (!GetConVarBool(g_disable_round_timer_cvar)) {
    return;
  }

  DisableRoundTimer();
}

public void OnPluginEnd() {
  if (!GetConVarBool(g_disable_round_timer_cvar)) {
    return;
  }

  EnableRoundTimer();
}