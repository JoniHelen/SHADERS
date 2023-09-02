using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TreeUpdater : MonoBehaviour
{
    private void Start()
    {
        UpdateAllTrees();
    }

    public void UpdateAllTrees()
    {
        var updaters = FindObjectsOfType<TreeModelMatrixUpdater>();
        foreach (var updater in updaters) {
            updater.UpdateTreeMatrices();
        }
    }
}
