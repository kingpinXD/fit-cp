package agent

// isValidMode reports whether mode is one the handler will accept. Empty is
// allowed and means "default to ModeChat" inside Run.
func isValidMode(mode Mode) bool {
	switch mode {
	case "", ModeChat, ModeCoach:
		return true
	}
	return false
}

// ResolveSystemPrompt picks the right system prompt for the mode.
// Falls back to the chat prompt for unknown modes (defensive only;
// handler should reject unknown modes upstream).
func ResolveSystemPrompt(mode Mode) string {
	switch mode {
	case ModeCoach:
		return coachSystemPrompt
	case ModeChat, "":
		return chatSystemPrompt
	default:
		return chatSystemPrompt
	}
}

// ResolveTools returns the tool subset for the given mode.
// ModeChat: search_exercises only.
// ModeCoach: search_exercises + propose_programme.
func ResolveTools(mode Mode, registry *Registry) []ToolDef {
	switch mode {
	case ModeCoach:
		return registry.SubsetDefs("search_exercises", "propose_programme")
	default:
		return registry.SubsetDefs("search_exercises")
	}
}
