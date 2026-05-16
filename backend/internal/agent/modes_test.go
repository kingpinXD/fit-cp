package agent

import (
	"testing"
)

func TestResolveSystemPromptByMode(t *testing.T) {
	cases := []struct {
		name string
		mode Mode
		want string
	}{
		{"chat", ModeChat, chatSystemPrompt},
		{"coach", ModeCoach, coachSystemPrompt},
		{"empty defaults to chat", "", chatSystemPrompt},
		{"unknown defaults to chat", Mode("banana"), chatSystemPrompt},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := ResolveSystemPrompt(tc.mode); got != tc.want {
				t.Errorf("ResolveSystemPrompt(%q): unexpected prompt", tc.mode)
			}
		})
	}
}

func TestResolveToolsByMode(t *testing.T) {
	reg := &Registry{handlers: map[string]ToolHandler{}}
	reg.register(ToolDef{Name: "search_exercises", Parameters: map[string]any{}}, nil)
	reg.register(ToolDef{Name: "propose_programme", Parameters: map[string]any{}}, nil)
	reg.register(ToolDef{Name: "secret_tool", Parameters: map[string]any{}}, nil)

	cases := []struct {
		name string
		mode Mode
		want []string
	}{
		{"chat exposes only search", ModeChat, []string{"search_exercises"}},
		{"empty defaults to chat", "", []string{"search_exercises"}},
		{"coach exposes search + propose", ModeCoach, []string{"search_exercises", "propose_programme"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := ResolveTools(tc.mode, reg)
			gotNames := make([]string, 0, len(got))
			for _, d := range got {
				gotNames = append(gotNames, d.Name)
			}
			if !equalSlices(gotNames, tc.want) {
				t.Errorf("ResolveTools(%q): got %v, want %v", tc.mode, gotNames, tc.want)
			}
		})
	}
}
