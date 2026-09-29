oauth_states = {}


def save_state(state, provider, user):
    oauth_states[state] = {
        "provider": provider,
        "user": user,
    }


def get_state(state):
    return oauth_states.get(state)


def delete_state(state):
    if state in oauth_states:
        del oauth_states[state]