package engine

import (
	"context"

	"github.com/redhat-appstudio/rhtap-cli/pkg/k8s"

	v1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// LookupFuncs represents the template functions that will need to lookup
// Kubernetes resources.
type LookupFuncs struct {
	kube *k8s.Kube
}

type LookupFn func(string, string, string, string) (map[string]interface{}, error)

func (l *LookupFuncs) lookup(
	apiVersion, kind, namespace, name string,
) (map[string]interface{}, error) {
	empty := map[string]interface{}{}

	client, err := l.kube.GetDynamicClientForObjectRef(&v1.ObjectReference{
		APIVersion: apiVersion,
		Kind:       kind,
		Namespace:  namespace,
		Name:       name,
	})
	if err != nil {
		return empty, err
	}

	ctx := context.Background()
	if name != "" {
		obj, err := client.Get(ctx, name, metav1.GetOptions{})
		if err != nil {
			if apierrors.IsNotFound(err) {
				return empty, nil
			}
			return empty, err
		}
		return obj.UnstructuredContent(), nil
	}

	objList, err := client.List(ctx, metav1.ListOptions{})
	if err != nil {
		if apierrors.IsNotFound(err) {
			return empty, nil
		}
		return empty, err
	}
	return objList.UnstructuredContent(), nil
}

func (l *LookupFuncs) Lookup() LookupFn {
	return l.lookup
}

// NewLookupFuncs creates a new LookupFuncs instance.
func NewLookupFuncs(kube *k8s.Kube) *LookupFuncs {
	return &LookupFuncs{kube: kube}
}
